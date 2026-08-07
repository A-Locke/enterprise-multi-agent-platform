"""Azure AI Content Safety: a dedicated moderation check on user input before it reaches
the LLM, authenticated via Entra ID (managed identity in Azure, `az login` locally) -- same
pattern as agent.py's Azure OpenAI connection, no API keys anywhere. Evaluated per ADR-0014:
defense-in-depth alongside the model's own default content filter, not a replacement for it.
"""

from azure.ai.contentsafety.aio import ContentSafetyClient
from azure.ai.contentsafety.models import AnalyzeTextOptions, TextCategory
from azure.core.exceptions import HttpResponseError
from azure.identity.aio import DefaultAzureCredential

from .config import settings

# 0-6 scale per category; 2 is Microsoft's own documented "medium" default threshold for
# blocking user-generated content (see Azure AI Content Safety severity level docs) -- not
# an arbitrary choice, matches the platform's own recommended baseline.
_BLOCK_SEVERITY_THRESHOLD = 2

_client: ContentSafetyClient | None = None


def get_client() -> ContentSafetyClient:
    """Lazily built, same reasoning as agent.py's get_kernel(): credential acquisition must
    not happen at import time, or test collection breaks."""
    global _client
    if _client is None:
        _client = ContentSafetyClient(
            endpoint=settings.azure_content_safety_endpoint,
            credential=DefaultAzureCredential(),
        )
    return _client


class ContentBlockedError(Exception):
    """Raised when input text exceeds the severity threshold in any harm category."""

    def __init__(self, category: str, severity: int):
        self.category = category
        self.severity = severity
        super().__init__(f"Content blocked: {category} severity {severity}")


async def check_text(text: str) -> None:
    """Raises ContentBlockedError if any harm category exceeds the block threshold.
    Fails open on a service error (logged, not raised) -- an unreachable moderation service
    should not itself become a denial-of-service vector for the whole chat endpoint."""
    client = get_client()
    try:
        response = await client.analyze_text(AnalyzeTextOptions(text=text))
    except HttpResponseError:
        return

    for category in (
        TextCategory.HATE,
        TextCategory.SELF_HARM,
        TextCategory.SEXUAL,
        TextCategory.VIOLENCE,
    ):
        result = next(
            (r for r in response.categories_analysis if r.category == category), None
        )
        if (
            result is not None
            and result.severity is not None
            and result.severity >= _BLOCK_SEVERITY_THRESHOLD
        ):
            raise ContentBlockedError(category=str(category), severity=result.severity)
