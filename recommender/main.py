"""Main script for testing and visualizing the recommendation engine."""

from sklearn.metrics.pairwise import cosine_similarity

from src.db import connect, load_board_games
from src.engine import RecommendationEngine
from src.features import build_feature_matrix
from src.preprocess import preprocess
from src.visualize import (
    plot_feature_distributions,
    plot_similarity_heatmap,
    plot_top_categories_and_mechanics,
)


def main() -> None:
    print("Connecting to database...")
    db_engine = connect()

    print("Loading board games...")
    df = load_board_games(db_engine)
    print(f"Loaded {len(df)} games")

    print("\nTop 10 by average rating (min 1000 ratings):")
    popular = df[df["users_rated"] >= 1000].nlargest(10, "average_rating")
    for _, row in popular.iterrows():
        print(f"  [{row['bgg_id']}] {row['name']} — {row['average_rating']:.2f} ({row['users_rated']} ratings)")

    # 1. Feature distributions
    print("\nPlotting feature distributions...")
    plot_feature_distributions(df)

    # 2. Category and mechanic frequency
    print("Plotting category & mechanic frequency...")
    plot_top_categories_and_mechanics(df)

    # 3. Build features (sparse) — local dense similarity matrix only for the heatmap viz
    print("Building feature matrix...")
    processed = preprocess(df)
    features = build_feature_matrix(processed)
    print(f"Feature matrix shape: {features.shape}, nnz: {features.nnz}")

    print("Computing similarity matrix for heatmap (top games subset)...")
    sim_matrix = cosine_similarity(features)
    plot_similarity_heatmap(sim_matrix, processed)

    # Sanity check — Catan recommendations via the engine (no full matrix needed)
    test_id = 13
    test_name = processed[processed["bgg_id"] == test_id]["name"].values
    if len(test_name) > 0:
        print(f"\nGames similar to '{test_name[0]}' (bgg_id={test_id}):")
        rec_engine = RecommendationEngine(db_engine)
        rec_engine.load()
        for r in rec_engine.recommend(test_id, top_n=10):
            print(f"  [{r['bgg_id']}] {r['name']} — similarity: {r['score']:.3f}")
    else:
        print(f"\nGame with bgg_id={test_id} not found in dataset")


if __name__ == "__main__":
    main()
