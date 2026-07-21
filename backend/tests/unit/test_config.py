from app.core.config import Settings


def test_settings_load_defaults() -> None:
    settings = Settings()
    assert settings.environment == "development"
    assert settings.api_v1_prefix == "/api/v1"


def test_settings_read_prefixed_env_vars(monkeypatch) -> None:
    monkeypatch.setenv("API_ENVIRONMENT", "staging")
    monkeypatch.setenv("API_LOG_LEVEL", "DEBUG")
    settings = Settings()
    assert settings.environment == "staging"
    assert settings.log_level == "DEBUG"


def test_database_url_defaults_to_asyncpg_driver() -> None:
    settings = Settings()
    assert str(settings.database_url).startswith("postgresql+asyncpg://")
