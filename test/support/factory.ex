defmodule Recco.Factory do
  use ExMachina.Ecto, repo: Recco.Repo

  alias Recco.Accounts.User
  alias Recco.Accounts.UserRating
  alias Recco.BoardGames.BoardGame
  alias Recco.BoardGames.CrawlState

  @spec user_factory() :: User.t()
  def user_factory do
    %User{
      email: sequence(:email, &"user#{&1}@example.com"),
      username: sequence(:username, &"user#{&1}"),
      hashed_password: Bcrypt.hash_pwd_salt("valid_password123"),
      role: "base"
    }
  end

  @spec board_game_factory() :: BoardGame.t()
  def board_game_factory do
    %BoardGame{
      bgg_id: sequence(:bgg_id, & &1),
      name: sequence(:board_game_name, &"Board Game #{&1}"),
      alternate_names: [],
      description: "A fun board game.",
      year_published: 2020,
      min_players: 2,
      max_players: 4,
      min_playtime: 30,
      max_playtime: 60,
      playing_time: 45,
      min_age: 10,
      image_url: "https://example.com/image.jpg",
      thumbnail_url: "https://example.com/thumb.jpg",
      average_rating: 7.5,
      bayes_average_rating: 7.0,
      users_rated: 1000,
      average_weight: 2.5,
      categories: [%{"id" => 1, "value" => "Strategy"}],
      mechanics: [%{"id" => 2, "value" => "Dice Rolling"}],
      designers: [%{"id" => 3, "value" => "Designer Name"}],
      artists: [],
      publishers: [],
      families: [],
      ranks: []
    }
  end

  @spec user_rating_factory() :: UserRating.t()
  def user_rating_factory do
    %UserRating{
      user: build(:user),
      board_game: build(:board_game),
      score: 7.5
    }
  end

  @spec crawl_state_factory() :: CrawlState.t()
  def crawl_state_factory do
    %CrawlState{
      key: sequence(:crawl_key, &"crawl_#{&1}"),
      last_fetched_id: 0,
      status: "idle",
      metadata: %{}
    }
  end
end
