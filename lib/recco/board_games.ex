defmodule Recco.BoardGames do
  import Ecto.Query

  alias Recco.BoardGames.BoardGame
  alias Recco.BoardGames.Category
  alias Recco.BoardGames.CrawlState
  alias Recco.BoardGames.Mechanic
  alias Recco.Errors
  alias Recco.Repo

  @spec upsert_board_game(map()) :: {:ok, BoardGame.t()} | Errors.t(map())
  def upsert_board_game(attrs) do
    %BoardGame{}
    |> BoardGame.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :bgg_id, :inserted_at]},
      conflict_target: :bgg_id,
      returning: true
    )
    |> Errors.handle_changeset_error()
  end

  @spec get_board_game_by_bgg_id(integer()) :: {:ok, BoardGame.t()} | Errors.t()
  def get_board_game_by_bgg_id(bgg_id) do
    case Repo.one(from bg in BoardGame, where: bg.bgg_id == ^bgg_id) do
      nil -> {:error, :not_found}
      board_game -> {:ok, board_game}
    end
  end

  @spec get_crawl_state(String.t()) :: {:ok, CrawlState.t()} | Errors.t()
  def get_crawl_state(key) do
    case Repo.one(from cs in CrawlState, where: cs.key == ^key) do
      nil -> {:error, :not_found}
      crawl_state -> {:ok, crawl_state}
    end
  end

  @spec board_game_count() :: non_neg_integer()
  def board_game_count do
    Repo.aggregate(BoardGame, :count)
  end

  @spec max_bgg_id() :: non_neg_integer()
  def max_bgg_id do
    Repo.aggregate(BoardGame, :max, :bgg_id) || 0
  end

  @type list_opts :: %{
          optional(:search) => String.t(),
          optional(:categories) => [String.t()],
          optional(:mechanics) => [String.t()],
          optional(:min_players) => pos_integer(),
          optional(:max_players) => pos_integer(),
          optional(:page) => pos_integer(),
          optional(:per_page) => pos_integer(),
          optional(:sort) => String.t(),
          optional(:sort_dir) => String.t()
        }

  @spec list_board_games(list_opts()) :: %{games: [BoardGame.t()], total: non_neg_integer()}
  def list_board_games(opts \\ %{}) do
    page = Map.get(opts, :page, 1)
    per_page = Map.get(opts, :per_page, 24)

    base = from(bg in BoardGame, where: not is_nil(bg.name) and bg.name != "")

    query =
      base
      |> apply_search(opts)
      |> apply_category(opts)
      |> apply_mechanic(opts)
      |> apply_player_count(opts)
      |> apply_sort(opts)

    total = Repo.aggregate(query, :count)

    games =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{games: games, total: total}
  end

  @spec get_board_game(String.t()) :: {:ok, BoardGame.t()} | Errors.t()
  def get_board_game(id) do
    case Repo.get(BoardGame, id) do
      nil -> {:error, :not_found}
      game -> {:ok, game}
    end
  end

  @spec get_board_games_by_bgg_ids([integer()]) :: %{integer() => BoardGame.t()}
  def get_board_games_by_bgg_ids([]), do: %{}

  def get_board_games_by_bgg_ids(bgg_ids) do
    from(bg in BoardGame, where: bg.bgg_id in ^bgg_ids)
    |> Repo.all()
    |> Map.new(&{&1.bgg_id, &1})
  end

  defp apply_search(query, %{search: search}) when is_binary(search) and search != "" do
    term = "%#{search}%"
    from bg in query, where: ilike(bg.name, ^term)
  end

  defp apply_search(query, _opts), do: query

  defp apply_category(query, %{categories: categories})
       when is_list(categories) and categories != [] do
    Enum.reduce(categories, query, fn cat, q ->
      from bg in q, where: fragment("? @> ?", bg.categories, ^[%{"value" => cat}])
    end)
  end

  defp apply_category(query, _opts), do: query

  defp apply_mechanic(query, %{mechanics: mechanics})
       when is_list(mechanics) and mechanics != [] do
    Enum.reduce(mechanics, query, fn mech, q ->
      from bg in q, where: fragment("? @> ?", bg.mechanics, ^[%{"value" => mech}])
    end)
  end

  defp apply_mechanic(query, _opts), do: query

  defp apply_player_count(query, %{min_players: n}) when is_integer(n) and n > 0 do
    from bg in query, where: bg.max_players >= ^n
  end

  defp apply_player_count(query, _opts), do: query

  defp apply_sort(query, opts) do
    dir = sort_direction(opts)

    case Map.get(opts, :sort) do
      "name" -> from(bg in query, order_by: [{^dir, bg.name}])
      "year" -> from(bg in query, order_by: [{^dir, bg.year_published}])
      "weight" -> from(bg in query, order_by: [{^dir, bg.average_weight}])
      _ -> from(bg in query, order_by: [{^dir, bg.bayes_average_rating}])
    end
  end

  defp sort_direction(%{sort_dir: "asc"}), do: :asc_nulls_last
  defp sort_direction(%{sort_dir: "desc"}), do: :desc_nulls_last

  defp sort_direction(opts) do
    case Map.get(opts, :sort) do
      "name" -> :asc_nulls_last
      _ -> :desc_nulls_last
    end
  end

  @spec upsert_crawl_state(String.t(), map()) :: {:ok, CrawlState.t()} | Errors.t(map())
  def upsert_crawl_state(key, attrs) do
    %CrawlState{}
    |> CrawlState.changeset(Map.put(attrs, :key, key))
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :key, :inserted_at]},
      conflict_target: :key,
      returning: true
    )
    |> Errors.handle_changeset_error()
  end

  # Taxonomy (categories & mechanics lookup tables)

  @spec list_categories() :: [Category.t()]
  def list_categories do
    from(c in Category, order_by: [asc: c.name]) |> Repo.all()
  end

  @spec list_mechanics() :: [Mechanic.t()]
  def list_mechanics do
    from(m in Mechanic, order_by: [asc: m.name]) |> Repo.all()
  end

  @spec sync_taxonomy() :: {non_neg_integer(), non_neg_integer()}
  def sync_taxonomy do
    cat_count = sync_table(Category, "categories")
    mech_count = sync_table(Mechanic, "mechanics")
    {cat_count, mech_count}
  end

  defp sync_table(schema, jsonb_field) do
    existing_bgg_ids =
      from(s in schema, select: s.bgg_id)
      |> Repo.all()
      |> MapSet.new()

    distinct_entries = extract_distinct_entries(jsonb_field)

    new_entries =
      distinct_entries
      |> Enum.reject(fn %{"id" => id} -> MapSet.member?(existing_bgg_ids, id) end)

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows =
      Enum.map(new_entries, fn %{"id" => id, "value" => name} ->
        %{
          id: Ecto.UUID.generate(),
          bgg_id: id,
          name: name,
          inserted_at: now,
          updated_at: now
        }
      end)

    case rows do
      [] ->
        0

      rows ->
        {count, _} = Repo.insert_all(schema, rows, on_conflict: :nothing)
        count
    end
  end

  defp extract_distinct_entries(jsonb_field) do
    query =
      from(bg in BoardGame,
        select:
          fragment(
            "DISTINCT jsonb_array_elements(?)",
            field(bg, ^String.to_existing_atom(jsonb_field))
          )
      )

    Repo.all(query)
    |> Enum.filter(fn entry ->
      is_map(entry) and not is_nil(entry["id"]) and not is_nil(entry["value"])
    end)
    |> Enum.uniq_by(fn entry -> entry["id"] end)
  end
end
