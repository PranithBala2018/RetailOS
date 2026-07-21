# RetailOS Architecture

## Overview

RetailOS is a cross-platform Retail ERP + POS platform built with a modular, scalable architecture.

## Platforms

- Android (Flutter)
- Windows Desktop (Flutter)
- Web (Future)
- iOS (Future)

## High-Level Architecture

Flutter App
      │
      ▼
 REST API Backend
      │
      ▼
 PostgreSQL Database

## Core Principles

- Clean Architecture
- Repository Pattern
- SOLID Principles
- Offline-first
- Multi-business
- Multi-branch
- Secure by default

## Major Modules

1. Authentication
2. Company Management
3. User & Roles
4. Product Management
5. Category Management
6. Customer Management
7. Supplier Management
8. Purchase Management
9. Inventory
10. POS Billing
11. Reports
12. Expenses
13. Notifications
14. Settings
15. Hardware Integration

## Hardware Support

- USB Thermal Printer
- Bluetooth Thermal Printer
- Barcode Scanner
- QR Scanner
- Cash Drawer
- Weighing Scale
- Customer Display

## Offline Strategy

- Local SQLite database
- Background synchronization
- Conflict resolution
- Automatic retry

## Security

- JWT Authentication
- Role-Based Access Control
- Encrypted local storage
- HTTPS communication
- Audit logs

## Scalability

The system must support:
- Single shop
- Multiple branches
- Multiple businesses
- Cloud deployment
- Thousands of concurrent users

---

## Implementation Status

See `SPRINT0.md` for the full architecture contract and `CHANGELOG.md`
for what shipped each sprint.

- **Sprint 1** — infrastructure foundation: FastAPI/SQLAlchemy/Alembic
  backend skeleton, Flutter/Riverpod/GoRouter/Drift frontend skeleton,
  Docker Compose, CI, JWT utilities (no persistence yet).
- **Sprint 2** — Identity & Organization: Company/Branch/Warehouse,
  Users/Roles/Permissions (RBAC), full authentication (login, refresh
  rotation with reuse detection, password reset framework, account
  lockout, device sessions, branch switching), and the corresponding
  Flutter screens (Splash, Login, Forgot/Reset Password, Company Setup
  Wizard, Branch Selection, Dashboard Shell, Navigation Shell, Profile).
  Tenant isolation is enforced at the application layer; Postgres RLS is
  deferred to Sprint 3 (`docs/adr/0003`).
- **Not yet implemented**: Products, Inventory, Purchases, Customers,
  Suppliers, POS/Billing, Reports, AI modules — per `TASKS.md`.
