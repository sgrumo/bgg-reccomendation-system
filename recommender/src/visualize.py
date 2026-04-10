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
        counts = _count_labels(df[col])
        sorted_counts = sorted(counts.items(), key=lambda x: x[1], reverse=True)[:top_n]
        names = [c[0] for c in sorted_counts]
        values = [c[1] for c in sorted_counts]

        ax.barh(names[::-1], values[::-1], edgecolor="black", alpha=0.7)
        ax.set_title(title)
        ax.set_xlabel("Count")

    fig.suptitle("Category & Mechanic Frequency", fontsize=14, fontweight="bold")
    fig.tight_layout()
    plt.show()


def plot_rating_vs_weight(df: pd.DataFrame) -> None:
    """Scatter plot of average rating vs complexity weight."""
    data = df[(df["average_weight"] > 0) & (df["users_rated"] >= 30)].copy()

    fig, ax = plt.subplots(figsize=(10, 7))
    scatter = ax.scatter(
        data["average_weight"],
        data["average_rating"],
        c=np.log1p(data["users_rated"]),
        cmap="viridis",
        alpha=0.3,
        s=5,
    )
    fig.colorbar(scatter, ax=ax, label="log(Users Rated)")
    ax.set_xlabel("Average Weight (Complexity)")
    ax.set_ylabel("Average Rating")
    ax.set_title("Rating vs Complexity", fontsize=14, fontweight="bold")
    fig.tight_layout()
    plt.show()


def plot_games_per_decade(df: pd.DataFrame) -> None:
    """Bar chart of game count by decade."""
    if "decade" not in df.columns:
        return

    decade_counts = df["decade"].value_counts().sort_index()
    decade_counts = decade_counts[decade_counts.index >= 1950]

    fig, ax = plt.subplots(figsize=(12, 5))
    ax.bar(
        decade_counts.index.astype(str),
        decade_counts.values,
        edgecolor="black",
        alpha=0.7,
    )
    ax.set_xlabel("Decade")
    ax.set_ylabel("Number of Games")
    ax.set_title("Games Published per Decade", fontsize=14, fontweight="bold")
    plt.xticks(rotation=45)
    fig.tight_layout()
    plt.show()


def plot_rating_tiers(df: pd.DataFrame) -> None:
    """Pie chart of rating tier distribution."""
    if "rating_tier" not in df.columns:
        return

    counts = df["rating_tier"].value_counts()

    fig, ax = plt.subplots(figsize=(8, 8))
    ax.pie(
        counts.values,
        labels=counts.index,
        autopct="%1.1f%%",
        startangle=140,
    )
    ax.set_title("Rating Tier Distribution", fontsize=14, fontweight="bold")
    fig.tight_layout()
    plt.show()


def plot_correlation_matrix(df: pd.DataFrame) -> None:
    """Heatmap of correlations between numeric features."""
    numeric_cols = [
        "average_rating", "average_weight", "users_rated",
        "min_players", "max_players", "min_playtime", "max_playtime",
        "min_age", "year_published",
    ]
    cols = [c for c in numeric_cols if c in df.columns]
    corr = df[cols].corr()

    fig, ax = plt.subplots(figsize=(10, 8))
    im = ax.imshow(corr, cmap="RdBu_r", vmin=-1, vmax=1)
    ax.set_xticks(range(len(cols)))
    ax.set_yticks(range(len(cols)))
    ax.set_xticklabels(cols, rotation=45, ha="right", fontsize=9)
    ax.set_yticklabels(cols, fontsize=9)

    for i in range(len(cols)):
        for j in range(len(cols)):
            ax.text(j, i, f"{corr.iloc[i, j]:.2f}", ha="center", va="center", fontsize=7)

    fig.colorbar(im, ax=ax, label="Pearson Correlation")
    ax.set_title("Feature Correlation Matrix", fontsize=14, fontweight="bold")
    fig.tight_layout()
    plt.show()


def plot_mechanic_vs_rating(df: pd.DataFrame, top_n: int = 20) -> None:
    """Box plot of ratings grouped by the most common mechanics."""
    from src.preprocess import extract_label_list

    rows: list[dict[str, str | float]] = []
    for _, game in df.iterrows():
        mechs = extract_label_list(game["mechanics"])
        for m in mechs:
            rows.append({"mechanic": m, "rating": game["average_rating"]})

    mech_df = pd.DataFrame(rows)
    top_mechs = mech_df["mechanic"].value_counts().head(top_n).index
    mech_df = mech_df[mech_df["mechanic"].isin(top_mechs)]

    medians = mech_df.groupby("mechanic")["rating"].median().sort_values(ascending=False)

    fig, ax = plt.subplots(figsize=(12, 8))
    positions = range(len(medians))
    box_data = [
        mech_df[mech_df["mechanic"] == m]["rating"].values for m in medians.index
    ]
    ax.boxplot(box_data, positions=positions, vert=False, widths=0.6)
    ax.set_yticks(positions)
    ax.set_yticklabels(medians.index, fontsize=9)
    ax.set_xlabel("Average Rating")
    ax.set_title(
        f"Rating Distribution by Mechanic (Top {top_n})",
        fontsize=14,
        fontweight="bold",
    )
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


def _count_labels(series: pd.Series) -> dict[str, int]:
    """Count label occurrences in a series of JSON arrays."""
    counts: dict[str, int] = {}
    for raw in series:
        items = raw if isinstance(raw, list) else json.loads(raw or "[]")
        for item in items:
            name = item.get("value") or item.get("name", "")
            if name:
                counts[name] = counts.get(name, 0) + 1
    return counts
