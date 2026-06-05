defmodule ReccoWeb.Admin.PrototypeLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    admin = insert(:user, role: "superadmin")
    conn = log_in_user(conn, admin)
    {:ok, conn: conn, admin: admin}
  end

  describe "Index" do
    test "redirects non-superadmins", %{conn: _admin_conn} do
      base_user = insert(:user, role: "base")
      conn = log_in_user(Phoenix.ConnTest.build_conn(), base_user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/prototypes")
    end

    test "lists all prototypes by default (active + blocked)", %{conn: conn} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      insert(:prototype, title: "Active proto")
      insert(:prototype, title: "Blocked proto", blocked_at: now)

      {:ok, _view, html} = live(conn, ~p"/admin/prototypes")

      assert html =~ "Active proto"
      assert html =~ "Blocked proto"
      assert html =~ "Active"
      assert html =~ "Blocked"
    end

    test "Active filter hides blocked", %{conn: conn} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      insert(:prototype, title: "Active proto")
      insert(:prototype, title: "Blocked proto", blocked_at: now)

      {:ok, _view, html} = live(conn, ~p"/admin/prototypes?filter=active")

      assert html =~ "Active proto"
      refute html =~ "Blocked proto"
    end

    test "Blocked filter shows only blocked", %{conn: conn} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      insert(:prototype, title: "Active proto")
      insert(:prototype, title: "Blocked proto", blocked_at: now)

      {:ok, _view, html} = live(conn, ~p"/admin/prototypes?filter=blocked")

      refute html =~ "Active proto"
      assert html =~ "Blocked proto"
    end

    test "Block button sets blocked_at", %{conn: conn} do
      prototype = insert(:prototype, title: "Will be blocked")

      {:ok, view, _html} = live(conn, ~p"/admin/prototypes")

      html =
        view
        |> element("button[phx-value-id='#{prototype.id}']", "Block")
        |> render_click()

      assert html =~ "Blocked"
      assert Recco.Prototypes.blocked?(Recco.Repo.get!(Recco.Prototypes.Prototype, prototype.id))
    end

    test "Unblock button clears blocked_at", %{conn: conn} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      prototype = insert(:prototype, title: "Will be unblocked", blocked_at: now)

      {:ok, view, _html} = live(conn, ~p"/admin/prototypes?filter=blocked")

      html =
        view
        |> element("button[phx-value-id='#{prototype.id}']", "Unblock")
        |> render_click()

      refute Recco.Prototypes.blocked?(Recco.Repo.get!(Recco.Prototypes.Prototype, prototype.id))
      refute html =~ "Will be unblocked"
    end

    test "shows a mailto link for each submitter", %{conn: conn} do
      user = insert(:user, email: "designer@example.com")
      insert(:prototype, user: user, title: "Contact me")

      {:ok, _view, html} = live(conn, ~p"/admin/prototypes")

      assert html =~ "mailto:designer@example.com"
      assert html =~ "Contact"
    end
  end
end
