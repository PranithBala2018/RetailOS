"""Concurrency correctness for the atomic stock-level upsert and the
transfer deadlock-avoidance ordering.

These need real, independently-committed Postgres transactions racing
against each other — the shared `db_session`/`client` fixtures (one
connection, one outer transaction, rolled back at the end of every test,
see `conftest.py`) can't produce that: two "sessions" built on one
connection can't actually execute overlapping statements, so they can't
exercise real row-lock contention. This file uses its own throwaway,
genuinely-committed setup/teardown instead, and drives concurrent
operations through independent sessions on their own connections.
"""

import asyncio
import uuid
from collections.abc import AsyncGenerator

import pytest_asyncio
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.core.db import create_engine
from app.core.exceptions import ValidationException
from app.core.security import hash_password
from app.modules.audit.models import AuditLog
from app.modules.company.models import Branch, Company, Warehouse
from app.modules.inventory.models import StockLevel, StockTransaction, StockTransfer
from app.modules.inventory.repository import StockLevelRepository
from app.modules.inventory.service import InventoryService
from app.modules.products_catalog.models import Product, ProductVariant, Unit
from app.modules.users_roles_permissions.models import User


@pytest_asyncio.fixture
async def concurrency_setup() -> AsyncGenerator[dict, None]:
    engine = create_engine()
    session_factory = async_sessionmaker(bind=engine, expire_on_commit=False)

    async with session_factory() as session:
        company = Company(id=uuid.uuid4(), name="Concurrency Test Co")
        session.add(company)
        await session.flush()

        branch = Branch(id=uuid.uuid4(), company_id=company.id, name="HQ", code="HQ-CONC")
        session.add(branch)
        await session.flush()

        warehouse_a = Warehouse(
            id=uuid.uuid4(), company_id=company.id, branch_id=branch.id, name="A", code="A-CONC"
        )
        warehouse_b = Warehouse(
            id=uuid.uuid4(), company_id=company.id, branch_id=branch.id, name="B", code="B-CONC"
        )
        session.add_all([warehouse_a, warehouse_b])
        await session.flush()

        unit_id = (
            await session.execute(select(Unit.id).where(Unit.abbreviation == "pcs").limit(1))
        ).scalar_one()

        product = Product(
            id=uuid.uuid4(),
            company_id=company.id,
            sku="CONC-001",
            name="Concurrency Widget",
            base_unit_id=unit_id,
            track_inventory=True,
            allow_negative_stock=False,
        )
        session.add(product)
        await session.flush()

        variant = ProductVariant(
            id=uuid.uuid4(),
            company_id=company.id,
            product_id=product.id,
            sku="CONC-001",
            purchase_price=0,
            selling_price=0,
        )
        session.add(variant)
        await session.flush()

        # A real user, not a random UUID — `audit_logs.user_id` has a
        # genuine FK to `users.id` (unlike the plain, unconstrained
        # `created_by`/`updated_by` columns `AuditMixin` puts on most
        # tables), and `InventoryService` writes an audit log entry for
        # every movement.
        user = User(
            id=uuid.uuid4(),
            company_id=company.id,
            email=f"concurrency-{uuid.uuid4()}@example.com",
            full_name="Concurrency Test User",
            password_hash=hash_password("not-used"),
        )
        session.add(user)
        await session.flush()
        await session.commit()

        ids = {
            "company_id": company.id,
            "warehouse_a_id": warehouse_a.id,
            "warehouse_b_id": warehouse_b.id,
            "variant_id": variant.id,
            "user_id": user.id,
        }

    yield ids

    async with session_factory() as session:
        await session.execute(
            delete(StockTransaction).where(StockTransaction.company_id == ids["company_id"])
        )
        await session.execute(
            delete(StockTransfer).where(StockTransfer.company_id == ids["company_id"])
        )
        await session.execute(delete(StockLevel).where(StockLevel.company_id == ids["company_id"]))
        await session.execute(
            delete(ProductVariant).where(ProductVariant.company_id == ids["company_id"])
        )
        await session.execute(delete(Product).where(Product.company_id == ids["company_id"]))
        await session.execute(delete(Warehouse).where(Warehouse.company_id == ids["company_id"]))
        await session.execute(delete(AuditLog).where(AuditLog.company_id == ids["company_id"]))
        await session.execute(delete(User).where(User.company_id == ids["company_id"]))
        await session.execute(delete(Branch).where(Branch.company_id == ids["company_id"]))
        await session.execute(delete(Company).where(Company.id == ids["company_id"]))
        await session.commit()

    await engine.dispose()


async def test_concurrent_stock_outs_cannot_together_oversell(concurrency_setup: dict) -> None:
    engine = create_engine()
    session_factory = async_sessionmaker(bind=engine, expire_on_commit=False)
    try:
        async with session_factory() as session:
            await InventoryService(session).stock_in(
                concurrency_setup["company_id"],
                concurrency_setup["user_id"],
                warehouse_id=concurrency_setup["warehouse_a_id"],
                product_variant_id=concurrency_setup["variant_id"],
                quantity=10,
            )
            await session.commit()

        async def attempt_stock_out() -> str:
            async with session_factory() as session:
                try:
                    await InventoryService(session).stock_out(
                        concurrency_setup["company_id"],
                        concurrency_setup["user_id"],
                        warehouse_id=concurrency_setup["warehouse_a_id"],
                        product_variant_id=concurrency_setup["variant_id"],
                        quantity=6,
                    )
                    await session.commit()
                    return "success"
                except ValidationException:
                    await session.rollback()
                    return "rejected"

        results = await asyncio.gather(attempt_stock_out(), attempt_stock_out())
        assert sorted(results) == ["rejected", "success"]

        async with session_factory() as session:
            level = await StockLevelRepository(session).get(
                concurrency_setup["company_id"],
                concurrency_setup["warehouse_a_id"],
                concurrency_setup["variant_id"],
            )
            assert level is not None
            assert level.quantity == 4
    finally:
        await engine.dispose()


async def test_concurrent_opposite_direction_transfers_do_not_deadlock(
    concurrency_setup: dict,
) -> None:
    engine = create_engine()
    session_factory = async_sessionmaker(bind=engine, expire_on_commit=False)
    try:
        async with session_factory() as session:
            service = InventoryService(session)
            await service.stock_in(
                concurrency_setup["company_id"],
                concurrency_setup["user_id"],
                warehouse_id=concurrency_setup["warehouse_a_id"],
                product_variant_id=concurrency_setup["variant_id"],
                quantity=20,
            )
            await service.stock_in(
                concurrency_setup["company_id"],
                concurrency_setup["user_id"],
                warehouse_id=concurrency_setup["warehouse_b_id"],
                product_variant_id=concurrency_setup["variant_id"],
                quantity=20,
            )
            await session.commit()

        async def transfer_a_to_b() -> None:
            async with session_factory() as session:
                await InventoryService(session).transfer(
                    concurrency_setup["company_id"],
                    concurrency_setup["user_id"],
                    from_warehouse_id=concurrency_setup["warehouse_a_id"],
                    to_warehouse_id=concurrency_setup["warehouse_b_id"],
                    product_variant_id=concurrency_setup["variant_id"],
                    quantity=5,
                )
                await session.commit()

        async def transfer_b_to_a() -> None:
            async with session_factory() as session:
                await InventoryService(session).transfer(
                    concurrency_setup["company_id"],
                    concurrency_setup["user_id"],
                    from_warehouse_id=concurrency_setup["warehouse_b_id"],
                    to_warehouse_id=concurrency_setup["warehouse_a_id"],
                    product_variant_id=concurrency_setup["variant_id"],
                    quantity=3,
                )
                await session.commit()

        # Without the canonical lock-ordering fix, opposite-direction
        # transfers between the same warehouse pair can deadlock; both
        # completing well under Postgres's ~1s deadlock_timeout proves
        # the ordering fix is actually in effect, not just untested.
        await asyncio.wait_for(asyncio.gather(transfer_a_to_b(), transfer_b_to_a()), timeout=5)

        async with session_factory() as session:
            repo = StockLevelRepository(session)
            level_a = await repo.get(
                concurrency_setup["company_id"],
                concurrency_setup["warehouse_a_id"],
                concurrency_setup["variant_id"],
            )
            level_b = await repo.get(
                concurrency_setup["company_id"],
                concurrency_setup["warehouse_b_id"],
                concurrency_setup["variant_id"],
            )
            assert level_a is not None and level_a.quantity == 18
            assert level_b is not None and level_b.quantity == 22
    finally:
        await engine.dispose()


async def test_failed_policy_check_leaves_no_ledger_row(concurrency_setup: dict) -> None:
    engine = create_engine()
    session_factory = async_sessionmaker(bind=engine, expire_on_commit=False)
    try:
        async with session_factory() as session:
            raised = False
            try:
                await InventoryService(session).stock_out(
                    concurrency_setup["company_id"],
                    concurrency_setup["user_id"],
                    warehouse_id=concurrency_setup["warehouse_a_id"],
                    product_variant_id=concurrency_setup["variant_id"],
                    quantity=1,
                )
            except ValidationException:
                raised = True
            assert raised
            # No commit here — matches `get_db_session`'s real behavior
            # of rolling back on any exception rather than committing.

        async with session_factory() as session:
            count = await session.scalar(
                select(func.count())
                .select_from(StockTransaction)
                .where(StockTransaction.company_id == concurrency_setup["company_id"])
            )
            assert count == 0
    finally:
        await engine.dispose()
