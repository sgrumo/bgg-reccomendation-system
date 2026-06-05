defmodule Recco.PrototypesTest do
  use Recco.DataCase, async: true

  alias Recco.Prototypes
  alias Recco.Prototypes.Prototype

  setup do
    strategy = insert(:category, name: "Strategy")
    dice = insert(:mechanic, name: "Dice Rolling")
    {:ok, strategy: strategy, dice: dice}
  end

  defp valid_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "title" => "Castle Caper",
        "description" => "A heist game for clever cats.",
        "min_players" => 2,
        "max_players" => 4,
        "min_playtime" => 30,
        "max_playtime" => 60,
        "categories" => ["Strategy"],
        "mechanics" => ["Dice Rolling"],
        "collaborators" => [%{"name" => "Alice", "role" => "Designer"}],
        "contact_email" => "alice@example.com"
      },
      overrides
    )
  end

  describe "create_prototype/2" do
    test "creates a prototype with valid attrs" do
      user = insert(:user)

      assert {:ok, %Prototype{} = prototype} =
               Prototypes.create_prototype(user, valid_attrs())

      assert prototype.user_id == user.id
      assert prototype.title == "Castle Caper"
      assert prototype.categories == ["Strategy"]
      assert prototype.mechanics == ["Dice Rolling"]
      assert [collab] = prototype.collaborators
      assert collab.name == "Alice"
    end

    test "rejects when min_players > max_players" do
      user = insert(:user)

      assert {:error, :unprocessable_entity, errors} =
               Prototypes.create_prototype(user, valid_attrs(%{"min_players" => 5}))

      assert errors[:max_players]
    end

    test "rejects when min_playtime > max_playtime" do
      user = insert(:user)

      assert {:error, :unprocessable_entity, errors} =
               Prototypes.create_prototype(user, valid_attrs(%{"min_playtime" => 999}))

      assert errors[:max_playtime]
    end

    test "rejects empty categories" do
      user = insert(:user)

      assert {:error, :unprocessable_entity, errors} =
               Prototypes.create_prototype(user, valid_attrs(%{"categories" => []}))

      assert errors[:categories]
    end

    test "rejects unknown categories" do
      user = insert(:user)

      assert {:error, :unprocessable_entity, errors} =
               Prototypes.create_prototype(user, valid_attrs(%{"categories" => ["Made-up"]}))

      assert errors[:categories]
    end

    test "rejects unknown mechanics" do
      user = insert(:user)

      assert {:error, :unprocessable_entity, errors} =
               Prototypes.create_prototype(user, valid_attrs(%{"mechanics" => ["Made-up"]}))

      assert errors[:mechanics]
    end

    test "rejects invalid email" do
      user = insert(:user)

      assert {:error, :unprocessable_entity, errors} =
               Prototypes.create_prototype(
                 user,
                 valid_attrs(%{"contact_email" => "not-an-email"})
               )

      assert errors[:contact_email]
    end

    test "rejects when no collaborators" do
      user = insert(:user)

      assert {:error, :unprocessable_entity, errors} =
               Prototypes.create_prototype(user, valid_attrs(%{"collaborators" => []}))

      assert errors[:collaborators]
    end

    test "rejects collaborator missing role" do
      user = insert(:user)

      attrs = valid_attrs(%{"collaborators" => [%{"name" => "Alice", "role" => ""}]})

      assert {:error, :unprocessable_entity, _} = Prototypes.create_prototype(user, attrs)
    end
  end

  describe "list_prototypes/1" do
    test "returns all prototypes by default" do
      insert(:prototype)
      insert(:prototype)

      assert %{prototypes: prototypes, total: 2} = Prototypes.list_prototypes()
      assert length(prototypes) == 2
    end

    test "scopes to a user when :user_id given" do
      mine = insert(:user)
      insert(:prototype, user: mine)
      insert(:prototype)

      assert %{prototypes: [p], total: 1} = Prototypes.list_prototypes(%{user_id: mine.id})
      assert p.user_id == mine.id
    end

    test "paginates" do
      Enum.each(1..5, fn _ -> insert(:prototype) end)

      assert %{prototypes: page1, total: 5} =
               Prototypes.list_prototypes(%{page: 1, per_page: 2})

      assert length(page1) == 2
    end
  end

  describe "get_prototype/1" do
    test "returns ok tuple with preloads" do
      prototype = insert(:prototype)

      assert {:ok, loaded} = Prototypes.get_prototype(prototype.id)
      assert loaded.id == prototype.id
      assert %_{} = loaded.user
      assert is_list(loaded.images)
    end

    test "returns :not_found for missing id" do
      assert {:error, :not_found} = Prototypes.get_prototype(Ecto.UUID.generate())
    end
  end

  describe "update_prototype/3" do
    test "owner can update" do
      prototype = insert(:prototype)

      assert {:ok, updated} =
               Prototypes.update_prototype(
                 prototype,
                 prototype.user,
                 valid_attrs(%{"title" => "New"})
               )

      assert updated.title == "New"
    end

    test "non-owner is forbidden" do
      prototype = insert(:prototype)
      other = insert(:user)

      assert {:error, :forbidden} =
               Prototypes.update_prototype(prototype, other, valid_attrs(%{"title" => "Hack"}))
    end
  end

  describe "delete_prototype/2" do
    test "owner can delete" do
      prototype = insert(:prototype)
      assert :ok = Prototypes.delete_prototype(prototype, prototype.user)
      assert {:error, :not_found} = Prototypes.get_prototype(prototype.id)
    end

    test "non-owner is forbidden" do
      prototype = insert(:prototype)
      other = insert(:user)
      assert {:error, :forbidden} = Prototypes.delete_prototype(prototype, other)
      assert {:ok, _} = Prototypes.get_prototype(prototype.id)
    end
  end

  describe "owns?/2" do
    test "true when user_id matches" do
      prototype = insert(:prototype)
      assert Prototypes.owns?(prototype, prototype.user)
    end

    test "false otherwise" do
      prototype = insert(:prototype)
      refute Prototypes.owns?(prototype, insert(:user))
    end
  end

  describe "add_image/3" do
    test "adds an image with position 0 when none exist" do
      prototype = insert(:prototype)

      assert {:ok, image} = Prototypes.add_image(prototype, "p/1.png", "first.png")
      assert image.position == 0
    end

    test "increments position for subsequent images" do
      prototype = insert(:prototype)
      {:ok, _} = Prototypes.add_image(prototype, "p/1.png", "first.png")

      assert {:ok, image2} = Prototypes.add_image(prototype, "p/2.png", "second.png")
      assert image2.position == 1
    end
  end

  describe "delete_image/2" do
    test "owner can delete" do
      prototype = insert(:prototype)
      {:ok, image} = Prototypes.add_image(prototype, "p/1.png", "first.png")

      assert {:ok, _} = Prototypes.delete_image(image, prototype.user)
    end

    test "non-owner forbidden" do
      prototype = insert(:prototype)
      {:ok, image} = Prototypes.add_image(prototype, "p/1.png", "first.png")
      other = insert(:user)

      assert {:error, :forbidden} = Prototypes.delete_image(image, other)
    end
  end
end
