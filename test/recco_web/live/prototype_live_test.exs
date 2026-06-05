defmodule ReccoWeb.PrototypeLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "auth gating" do
    test "redirects unauthenticated users from index", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/prototypes")
    end

    test "redirects unauthenticated users from new", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/prototypes/new")
    end

    test "redirects unauthenticated users from show", %{conn: conn} do
      prototype = insert(:prototype)
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/prototypes/#{prototype.id}")
    end

    test "redirects unauthenticated users from edit", %{conn: conn} do
      prototype = insert(:prototype)

      assert {:error, {:redirect, %{to: "/login"}}} =
               live(conn, ~p"/prototypes/#{prototype.id}/edit")
    end
  end

  describe "Index" do
    test "shows empty state when no prototypes", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/prototypes")

      assert html =~ "No prototypes yet"
    end

    test "lists existing prototypes", %{conn: conn} do
      user = insert(:user)
      insert(:prototype, title: "Castle Caper")
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/prototypes")

      assert html =~ "Castle Caper"
    end

    test "Mine toggle scopes to current user", %{conn: conn} do
      user = insert(:user)
      insert(:prototype, user: user, title: "My Prototype")
      insert(:prototype, title: "Other Prototype")
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/prototypes?mine=1")

      assert html =~ "My Prototype"
      refute html =~ "Other Prototype"
    end
  end

  describe "Show" do
    test "renders prototype details", %{conn: conn} do
      user = insert(:user)
      prototype = insert(:prototype, title: "Castle Caper")
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/prototypes/#{prototype.id}")

      assert html =~ "Castle Caper"
      assert html =~ prototype.contact_email
    end

    test "shows Edit and Delete buttons only for owner", %{conn: conn} do
      owner = insert(:user)
      other = insert(:user)
      prototype = insert(:prototype, user: owner)

      conn_owner = log_in_user(conn, owner)
      {:ok, _view, html_owner} = live(conn_owner, ~p"/prototypes/#{prototype.id}")
      assert html_owner =~ "Edit"
      assert html_owner =~ "Delete"

      conn_other = log_in_user(conn, other)
      {:ok, _view, html_other} = live(conn_other, ~p"/prototypes/#{prototype.id}")
      refute html_other =~ ">Edit<"
      refute html_other =~ ">Delete<"
    end

    test "owner can delete from show page", %{conn: conn} do
      owner = insert(:user)
      prototype = insert(:prototype, user: owner)
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/prototypes/#{prototype.id}")

      assert {:error, {:redirect, %{to: "/prototypes"}}} =
               view |> element("button", "Delete") |> render_click()
    end

    test "clicking an image opens the lightbox", %{conn: conn} do
      user = insert(:user)
      prototype = insert(:prototype)
      insert(:prototype_image, prototype: prototype, position: 0)
      insert(:prototype_image, prototype: prototype, position: 1)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/prototypes/#{prototype.id}")

      refute render(view) =~ ~s(id="prototype-lightbox")

      html =
        view
        |> element(~s(button[phx-value-index="0"]))
        |> render_click()

      assert html =~ ~s(id="prototype-lightbox")
      assert html =~ "1 / 2"
    end

    test "lightbox next/prev navigates between images", %{conn: conn} do
      user = insert(:user)
      prototype = insert(:prototype)
      insert(:prototype_image, prototype: prototype, position: 0)
      insert(:prototype_image, prototype: prototype, position: 1)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/prototypes/#{prototype.id}")

      view |> element(~s(button[phx-value-index="0"])) |> render_click()

      html = view |> element("button[phx-click=next_image]") |> render_click()
      assert html =~ "2 / 2"

      html = view |> element("button[phx-click=prev_image]") |> render_click()
      assert html =~ "1 / 2"
    end

    test "close button hides the lightbox", %{conn: conn} do
      user = insert(:user)
      prototype = insert(:prototype)
      insert(:prototype_image, prototype: prototype, position: 0)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/prototypes/#{prototype.id}")

      view |> element(~s(button[phx-value-index="0"])) |> render_click()
      html = view |> element("button[aria-label='Close']") |> render_click()

      refute html =~ ~s(id="prototype-lightbox")
    end
  end

  describe "Form (new)" do
    setup do
      insert(:category, name: "Strategy")
      insert(:mechanic, name: "Dice Rolling")
      :ok
    end

    test "renders new form", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/prototypes/new")

      assert html =~ "Submit a prototype"
      assert html =~ "Categories"
      assert html =~ "Mechanics"
    end

    test "create flow saves and redirects", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/prototypes/new")

      params = %{
        "prototype" => %{
          "title" => "Castle Caper",
          "description" => "A heist game",
          "min_players" => "2",
          "max_players" => "4",
          "min_playtime" => "30",
          "max_playtime" => "60",
          "contact_email" => "alice@example.com"
        },
        "collab" => %{"0" => %{"name" => "Alice", "role" => "Designer"}}
      }

      view |> element("form") |> render_change(params)

      view
      |> element("#prototype-category-picker")
      |> render_hook("filter_categories", %{"selected" => ["Strategy"]})

      view
      |> element("#prototype-mechanic-picker")
      |> render_hook("filter_mechanics", %{"selected" => ["Dice Rolling"]})

      assert {:error, {:redirect, %{to: "/prototypes/" <> _}}} =
               view |> element("form") |> render_submit(params)
    end

    test "add_collab adds a row", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/prototypes/new")

      html = view |> element("button", "Add member") |> render_click()
      assert html =~ ~s(name="collab[1][name]")
    end
  end

  describe "Show with blocked prototype" do
    setup do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      {:ok, now: now}
    end

    test "non-owner is redirected to index", %{conn: conn, now: now} do
      blocked = insert(:prototype, blocked_at: now)
      conn = log_in_user(conn, insert(:user))

      assert {:error, {:redirect, %{to: "/prototypes"}}} =
               live(conn, ~p"/prototypes/#{blocked.id}")
    end

    test "owner can still view their blocked prototype", %{conn: conn, now: now} do
      owner = insert(:user)
      blocked = insert(:prototype, user: owner, blocked_at: now, title: "Mine")
      conn = log_in_user(conn, owner)

      {:ok, _view, html} = live(conn, ~p"/prototypes/#{blocked.id}")
      assert html =~ "Mine"
      assert html =~ "blocked by an admin"
    end

    test "superadmin can view a blocked prototype", %{conn: conn, now: now} do
      admin = insert(:user, role: "superadmin")
      blocked = insert(:prototype, blocked_at: now, title: "Reported")
      conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(conn, ~p"/prototypes/#{blocked.id}")
      assert html =~ "Reported"
      assert html =~ "blocked by an admin"
    end
  end

  describe "Form (edit)" do
    test "non-owner is redirected away", %{conn: conn} do
      owner = insert(:user)
      other = insert(:user)
      prototype = insert(:prototype, user: owner)
      conn = log_in_user(conn, other)

      assert {:error, {:redirect, %{to: "/prototypes"}}} =
               live(conn, ~p"/prototypes/#{prototype.id}/edit")
    end

    test "owner can load edit form prefilled", %{conn: conn} do
      owner = insert(:user)
      prototype = insert(:prototype, user: owner, title: "Existing")
      conn = log_in_user(conn, owner)

      {:ok, _view, html} = live(conn, ~p"/prototypes/#{prototype.id}/edit")

      assert html =~ "Edit prototype"
      assert html =~ "Existing"
    end
  end
end
