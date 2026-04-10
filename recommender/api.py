"""FastAPI wrapper around the recommendation engine."""

from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel

from src.db import connect
from src.engine import RecommendationEngine


engine = RecommendationEngine(connect())


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncGenerator[None, None]:
    """Load the recommendation engine on startup."""
    engine.load()
    yield


app = FastAPI(title="Recco Recommender", lifespan=lifespan)


class UserRatings(BaseModel):
    """Request body for user-profile recommendations."""

    ratings: dict[int, float]


class GameRecommendation(BaseModel):
    """A single game recommendation."""

    bgg_id: int
    name: str
    score: float


class HealthResponse(BaseModel):
    """Health check response."""

    status: str
    game_count: int


@app.get("/health")
def health() -> HealthResponse:
    """Check if the engine is loaded and ready."""
    if not engine.is_loaded:
        raise HTTPException(status_code=503, detail="Engine not loaded")
    return HealthResponse(status="ok", game_count=engine.game_count)


@app.get("/games/{bgg_id}/recommendations")
def game_recommendations(
    bgg_id: int,
    top_n: int = Query(default=10, ge=1, le=50),
) -> list[GameRecommendation]:
    """Get games similar to the given game."""
    try:
        results = engine.recommend(bgg_id, top_n=top_n)
    except KeyError:
        raise HTTPException(status_code=404, detail=f"Game {bgg_id} not found")
    return [GameRecommendation(**r) for r in results]


@app.post("/users/recommendations")
def user_recommendations(
    body: UserRatings,
    top_n: int = Query(default=20, ge=1, le=50),
) -> list[GameRecommendation]:
    """Get recommendations based on user's rated games."""
    if not body.ratings:
        raise HTTPException(status_code=422, detail="Ratings cannot be empty")
    results = engine.recommend_for_user(body.ratings, top_n=top_n)
    return [GameRecommendation(**r) for r in results]
