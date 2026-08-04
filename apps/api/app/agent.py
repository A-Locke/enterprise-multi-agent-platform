"""Semantic Kernel orchestration: one chat-capable agent, authenticated to Azure OpenAI
via Entra ID (managed identity in Azure, `az login` locally) -- no API keys anywhere.
"""

from typing import cast

from azure.identity.aio import DefaultAzureCredential, get_bearer_token_provider
from semantic_kernel import Kernel
from semantic_kernel.connectors.ai.chat_completion_client_base import ChatCompletionClientBase
from semantic_kernel.connectors.ai.open_ai import (
    AzureChatCompletion,
    AzureChatPromptExecutionSettings,
)
from semantic_kernel.contents import ChatHistory

from .config import settings

_AZURE_COGNITIVE_SERVICES_SCOPE = "https://cognitiveservices.azure.com/.default"

_kernel: Kernel | None = None


def get_kernel() -> Kernel:
    """Lazily build the Kernel so credential acquisition doesn't happen at import time
    (breaks test collection, which stubs auth but never needs a real AI connection)."""
    global _kernel
    if _kernel is None:
        token_provider = get_bearer_token_provider(
            DefaultAzureCredential(), _AZURE_COGNITIVE_SERVICES_SCOPE
        )
        kernel = Kernel()
        kernel.add_service(
            AzureChatCompletion(
                service_id="chat",
                deployment_name=settings.azure_openai_deployment_name,
                endpoint=settings.azure_openai_endpoint,
                ad_token_provider=token_provider,
            )
        )
        _kernel = kernel
    return _kernel


async def chat(message: str) -> str:
    kernel = get_kernel()
    service = cast(ChatCompletionClientBase, kernel.get_service("chat"))

    history = ChatHistory()
    history.add_system_message(
        "You are a helpful enterprise assistant for the Enterprise Multi-Agent Platform. "
        "Keep answers concise."
    )
    history.add_user_message(message)

    response = await service.get_chat_message_content(
        chat_history=history,
        settings=AzureChatPromptExecutionSettings(),
    )
    return str(response)
