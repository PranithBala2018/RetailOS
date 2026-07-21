"""Application configuration, sourced exclusively from environment variables.

See SPRINT0.md §10 (Environment Strategy) and §11 (Secrets Management) —
no environment-conditional code branches beyond these config values.
"""

from functools import lru_cache
from typing import Literal

from pydantic import Field, PostgresDsn, RedisDsn
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        env_prefix="API_",
        extra="ignore",
    )

    # --- Application ---
    project_name: str = "RetailOS API"
    environment: Literal["development", "testing", "staging", "production"] = "development"
    api_v1_prefix: str = "/api/v1"
    debug: bool = False

    # --- Database ---
    database_url: PostgresDsn = Field(
        default=PostgresDsn("postgresql+asyncpg://retailos:retailos@localhost:5432/retailos")
    )
    db_echo: bool = False
    db_pool_size: int = 10
    db_max_overflow: int = 20

    # --- Redis (cache / rate-limit / future Celery broker, per SPRINT0 §22) ---
    redis_url: RedisDsn = Field(default=RedisDsn("redis://localhost:6379/0"))

    # --- JWT (see SPRINT0 §16) ---
    jwt_secret_key: str = Field(default="change-me-in-every-non-development-environment")
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    # "Remember me" duration vs. a plain session — see auth/service.py.
    refresh_token_expire_days: int = 30
    refresh_token_expire_days_session: int = 1

    # --- Account lockout ---
    max_failed_login_attempts: int = 5
    account_lockout_minutes: int = 15

    # --- CORS ---
    cors_allow_origins: list[str] = Field(default_factory=lambda: ["http://localhost:3000"])

    # --- Logging ---
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"
    log_json: bool = True


@lru_cache
def get_settings() -> Settings:
    """Settings are cached for the process lifetime; env vars are read once at startup."""
    return Settings()
