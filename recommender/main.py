"""Main script for testing and visualizing the recommendation engine."""

from src.db import connect, load_board_games
from src.features import build_feature_matrix
from src.similarity import compute_similarity_matrix, find_similar
from src.visualize import (
    plot_feature_distributions,
    plot_similarity_heatmap,
    plot_top_categories_and_mechanics,
)


def main() -> None:
    print("Connecting to database...")
    engine = connect()

    print("Loading board games...")
    df = load_board_games(engine)
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

    # 3. Build features and similarity
    print("Building feature matrix...")
    features = build_feature_matrix(df)
    print(f"Feature matrix shape: {features.shape}")

    print("Computing similarity matrix...")
    sim_matrix = compute_similarity_matrix(features)

    # Similarity heatmap for top rated games
    print("Plotting similarity heatmap...")
    plot_similarity_heatmap(sim_matrix, df)

    # Sanity check — Catan recommendations
    test_id = 13
    test_name = df[df["bgg_id"] == test_id]["name"].values
    if len(test_name) > 0:
        print(f"\nGames similar to '{test_name[0]}' (bgg_id={test_id}):")
        results = find_similar(test_id, sim_matrix, df, top_n=10)
        for r in results:
            print(f"  [{r['bgg_id']}] {r['name']} — similarity: {r['score']:.3f}")
    else:
        print(f"\nGame with bgg_id={test_id} not found in dataset")


if __name__ == "__main__":
    main()
