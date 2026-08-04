"""Milestone 2: one working Semantic Kernel agent, end to end."""

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from ..agent import chat as agent_chat
from ..auth import require_any_role

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
    reply = await agent_chat(request.message)
    return ChatResponse(reply=reply)
