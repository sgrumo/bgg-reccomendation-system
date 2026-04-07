"""Database connection and queries for board game data."""

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

import pandas as pd


def connect(
    host: str = "localhost",
    port: int = 5460,
    database: str = "recco_dev",
    user: str = "postgres",
    password: str = "postgres",
) -> Engine:
    """Create a SQLAlchemy engine connected to the Recco database."""
    url = f"postgresql://{user}:{password}@{host}:{port}/{database}"
    return create_engine(url)


def load_board_games(engine: Engine) -> pd.DataFrame:
    """Load all board games from the database into a DataFrame."""
    query = text("""
        SELECT
            bgg_id, name, description, year_published,
            min_players, max_players, min_playtime, max_playtime,
            playing_time, min_age, average_rating, bayes_average_rating,
            users_rated, average_weight, categories, mechanics,
            designers, families
        FROM board_games
        WHERE users_rated > 0
        ORDER BY bgg_id
    """)
    return pd.read_sql(query, engine)
