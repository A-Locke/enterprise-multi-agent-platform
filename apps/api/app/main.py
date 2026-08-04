from fastapi import FastAPI

from .routers import agent, demo, health

app = FastAPI(title="Enterprise Multi-Agent Platform API", version="0.1.0")

app.include_router(health.router)
app.include_router(demo.router)
app.include_router(agent.router)
