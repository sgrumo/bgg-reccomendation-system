"""Visualization functions for board game data and recommendations."""

import json

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


def plot_feature_distributions(df: pd.DataFrame) -> None:
    """Plot histograms of key numeric features."""
    features = {
        "average_rating": "Average Rating",
        "average_weight": "Average Weight (Complexity)",
        "max_players": "Max Players",
        "max_playtime": "Max Playtime (min)",
        "users_rated": "Number of Ratings",
        "year_published": "Year Published",
    }

    fig, axes = plt.subplots(2, 3, figsize=(15, 8))
    axes = axes.flatten()

    for ax, (col, title) in zip(axes, features.items()):
        data = df[col].dropna()

        # Clip outliers for readability
        if col == "max_players":
            data = data[data <= 20]
        elif col == "max_playtime":
            data = data[data <= 300]
        elif col == "users_rated":
            data = data[data <= 10_000]

        ax.hist(data, bins=50, edgecolor="black", alpha=0.7)
        ax.set_title(title)
        ax.set_ylabel("Count")

    fig.suptitle("Feature Distributions", fontsize=14, fontweight="bold")
    fig.tight_layout()
    plt.show()


def plot_top_categories_and_mechanics(df: pd.DataFrame, top_n: int = 25) -> None:
    """Plot bar charts of the most frequent categories and mechanics."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 8))

    for ax, col, title in [
        (ax1, "categories", "Top Categories"),
        (ax2, "mechanics", "Top Mechanics"),
    ]:
        counts: dict[str, int] = {}
        for raw in df[col]:
            items = raw if isinstance(raw, list) else json.loads(raw or "[]")
            for item in items:
                name = item.get("name", "")
                if name:
                    counts[name] = counts.get(name, 0) + 1

        sorted_counts = sorted(counts.items(), key=lambda x: x[1], reverse=True)[:top_n]
        names = [c[0] for c in sorted_counts]
        values = [c[1] for c in sorted_counts]

        ax.barh(names[::-1], values[::-1], edgecolor="black", alpha=0.7)
        ax.set_title(title)
        ax.set_xlabel("Count")

    fig.suptitle("Category & Mechanic Frequency", fontsize=14, fontweight="bold")
    fig.tight_layout()
    plt.show()


def plot_similarity_heatmap(
    similarity_matrix: np.ndarray,
    df: pd.DataFrame,
    top_n: int = 40,
) -> None:
    """Plot a similarity heatmap for the top N games by number of ratings."""
    top_games = df.nlargest(top_n, "users_rated")
    indices = top_games.index.tolist()
    names = top_games["name"].tolist()

    sub_matrix = similarity_matrix[np.ix_(indices, indices)]

    fig, ax = plt.subplots(figsize=(14, 12))
    im = ax.imshow(sub_matrix, cmap="YlOrRd", vmin=0, vmax=1)

    ax.set_xticks(range(len(names)))
    ax.set_yticks(range(len(names)))
    ax.set_xticklabels(names, rotation=90, fontsize=7)
    ax.set_yticklabels(names, fontsize=7)

    fig.colorbar(im, ax=ax, label="Cosine Similarity")
    fig.suptitle(
        f"Similarity Heatmap (Top {top_n} Most Rated Games)",
        fontsize=14,
        fontweight="bold",
    )
    fig.tight_layout()
    plt.show()
