from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Environment-driven configuration. No hardcoded tenant/client IDs anywhere in code."""

    model_config = SettingsConfigDict(env_file=None, extra="ignore")

    azure_tenant_id: str
    azure_api_app_client_id: str

    @property
    def issuer(self) -> str:
        return f"https://login.microsoftonline.com/{self.azure_tenant_id}/v2.0"

    @property
    def jwks_uri(self) -> str:
        return f"https://login.microsoftonline.com/{self.azure_tenant_id}/discovery/v2.0/keys"

    @property
    def audience(self) -> list[str]:
        # Entra ID issues the bare client-id GUID as `aud` for this app's own exposed
        # scope (verified empirically via the device-code demo), but other flows/token
        # configurations can issue the App ID URI form instead -- accept both rather
        # than hardcode one observed behavior as the only valid case.
        return [self.azure_api_app_client_id, f"api://{self.azure_api_app_client_id}"]


settings = Settings()  # type: ignore[call-arg]  # fields are populated from env vars at runtime
