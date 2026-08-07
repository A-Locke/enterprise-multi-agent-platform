"""Milestone 2: one working Semantic Kernel agent, end to end."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from ..agent import chat as agent_chat
from ..auth import require_any_role
from ..content_safety import ContentBlockedError, check_text

router = APIRouter()


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    reply: str


@router.post("/agent/chat", response_model=ChatResponse)
async def agent_chat_endpoint(
    request: ChatRequest,
    claims: dict = Depends(require_any_role("Admin", "Agent.User")),
) -> ChatResponse:
    try:
        await check_text(request.message)
    except ContentBlockedError as exc:
        raise HTTPException(
            status_code=400, detail="Message blocked by content safety policy"
        ) from exc

    reply = await agent_chat(request.message)
    return ChatResponse(reply=reply)
