import pytest

from app import content_safety
from app.content_safety import ContentBlockedError, check_text


class FakeCategoryResult:
    def __init__(self, category: str, severity: int):
        self.category = category
        self.severity = severity


class FakeAnalyzeResponse:
    def __init__(self, categories_analysis: list[FakeCategoryResult]):
        self.categories_analysis = categories_analysis


class FakeClient:
    def __init__(self, response: FakeAnalyzeResponse):
        self._response = response

    async def analyze_text(self, _options):
        return self._response


@pytest.fixture(autouse=True)
def reset_client():
    content_safety._client = None
    yield
    content_safety._client = None


async def test_check_text_allows_low_severity(monkeypatch):
    response = FakeAnalyzeResponse([FakeCategoryResult("Violence", severity=0)])
    monkeypatch.setattr(content_safety, "get_client", lambda: FakeClient(response))

    await check_text("a harmless message")  # should not raise


async def test_check_text_blocks_high_severity(monkeypatch):
    response = FakeAnalyzeResponse([FakeCategoryResult("Hate", severity=4)])
    monkeypatch.setattr(content_safety, "get_client", lambda: FakeClient(response))

    with pytest.raises(ContentBlockedError) as exc_info:
        await check_text("something objectionable")
    assert exc_info.value.severity == 4


async def test_check_text_fails_open_on_service_error(monkeypatch):
    from azure.core.exceptions import HttpResponseError

    class FailingClient:
        async def analyze_text(self, _options):
            raise HttpResponseError("service unavailable")

    monkeypatch.setattr(content_safety, "get_client", lambda: FailingClient())

    await check_text("anything")  # should not raise -- fails open, not closed
