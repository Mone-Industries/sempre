#!/usr/bin/env python3
"""
browser-use HTTP Server — AI-driven browser agent.

The LLM (via Ollama) decides every action autonomously given a task description.

Endpoints:
  POST /run      {"task": "...", "max_steps": 20}  → run task, returns result
  GET  /health   liveness check
"""
import os
import asyncio
import uvicorn
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from browser_use import Agent, ChatOpenAI
from browser_use.browser.session import BrowserSession

app = FastAPI(title="browser-use")

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://ollama:11434/v1")
OLLAMA_MODEL    = os.getenv("OLLAMA_MODEL", "minimax-m2.5:cloud")

BROWSER_ARGS = [
    "--no-sandbox",
    "--disable-dev-shm-usage",
    "--disable-gpu",
    "--disable-software-rasterizer",
]


def make_llm() -> ChatOpenAI:
    return ChatOpenAI(
        model=OLLAMA_MODEL,
        base_url=OLLAMA_BASE_URL,
        api_key="ollama",
    )


class RunRequest(BaseModel):
    task: str
    max_steps: int = 20
    return_cookies: bool = False  # set true to get session cookies back (for passing to crawl4ai)


@app.get("/health")
async def health():
    return {"ok": True}


@app.post("/run")
async def run_task(req: RunRequest):
    # Fresh BrowserSession per request — avoids stale/crashed session state
    session = BrowserSession(
        headless=True,
        args=BROWSER_ARGS,
    )
    try:
        agent = Agent(task=req.task, llm=make_llm(), browser_session=session)
        result = await agent.run(max_steps=req.max_steps)
        response: dict = {"ok": True, "result": str(result)}

        if req.return_cookies:
            try:
                ctx = getattr(session, "browser_context", None) or getattr(session, "context", None)
                response["cookies"] = await ctx.cookies() if ctx else []
            except Exception:
                response["cookies"] = []

        return response
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})
    finally:
        try:
            await session.close()
        except Exception:
            pass


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level="warning")
