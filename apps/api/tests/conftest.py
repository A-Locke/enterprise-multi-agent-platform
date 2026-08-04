import os

# Must be set before app.config is imported anywhere (module-level Settings()).
os.environ.setdefault("AZURE_TENANT_ID", "test-tenant-id")
os.environ.setdefault("AZURE_API_APP_CLIENT_ID", "test-client-id")
os.environ.setdefault("AZURE_OPENAI_ENDPOINT", "https://test-openai.openai.azure.com/")
os.environ.setdefault("AZURE_OPENAI_DEPLOYMENT_NAME", "test-deployment")
