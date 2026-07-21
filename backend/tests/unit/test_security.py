from datetime import UTC, datetime, timedelta

import pytest

from app.core import security
from app.core.config import Settings


@pytest.fixture
def settings() -> Settings:
    return Settings(jwt_secret_key="unit-test-secret-key-of-sufficient-length")


def test_password_hash_roundtrip() -> None:
    hashed = security.hash_password("correct horse battery staple")
    assert security.verify_password("correct horse battery staple", hashed) is True


def test_password_hash_rejects_wrong_password() -> None:
    hashed = security.hash_password("correct horse battery staple")
    assert security.verify_password("wrong password", hashed) is False


def test_password_hash_is_salted() -> None:
    a = security.hash_password("same-password")
    b = security.hash_password("same-password")
    assert a != b


def test_access_token_round_trip(settings: Settings) -> None:
    token = security.create_access_token("user-1", company_id="company-1", settings=settings)
    payload = security.decode_token(
        token, expected_type=security.TokenType.ACCESS, settings=settings
    )
    assert payload.sub == "user-1"
    assert payload.company_id == "company-1"
    assert payload.token_type == security.TokenType.ACCESS


def test_refresh_token_has_longer_expiry_than_access_token(settings: Settings) -> None:
    access = security.decode_token(
        security.create_access_token("user-1", settings=settings), settings=settings
    )
    refresh = security.decode_token(
        security.create_refresh_token("user-1", settings=settings), settings=settings
    )
    assert refresh.exp > access.exp


def test_decode_rejects_wrong_token_type(settings: Settings) -> None:
    token = security.create_refresh_token("user-1", settings=settings)
    with pytest.raises(security.InvalidTokenError):
        security.decode_token(token, expected_type=security.TokenType.ACCESS, settings=settings)


def test_decode_rejects_expired_token(settings: Settings) -> None:
    token = security._create_token(
        subject="user-1",
        token_type=security.TokenType.ACCESS,
        expires_delta=timedelta(seconds=-1),
        company_id=None,
        settings=settings,
    )
    with pytest.raises(security.InvalidTokenError):
        security.decode_token(token, settings=settings)


def test_decode_rejects_token_signed_with_different_secret(settings: Settings) -> None:
    token = security.create_access_token("user-1", settings=settings)
    other_settings = Settings(jwt_secret_key="a-completely-different-secret-key-value")
    with pytest.raises(security.InvalidTokenError):
        security.decode_token(token, settings=other_settings)


def test_decode_rejects_garbage_token(settings: Settings) -> None:
    with pytest.raises(security.InvalidTokenError):
        security.decode_token("not-a-jwt", settings=settings)


def test_token_iat_is_recent(settings: Settings) -> None:
    token = security.create_access_token("user-1", settings=settings)
    payload = security.decode_token(token, settings=settings)
    assert datetime.now(UTC) - payload.iat < timedelta(seconds=5)
