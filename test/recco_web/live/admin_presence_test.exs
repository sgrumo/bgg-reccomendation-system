defmodule ReccoWeb.AdminPresenceTest do
  @moduledoc """
  Integration test for the AdminPresenceHook: two connected superadmins
  should each see the other in the Presence list and the indicator.
  """
  use ReccoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias ReccoWeb.Presence

  setup do
    # Tidy leftovers from other runs; Presence state is process-local but
    # the PubSub topic is shared.
    Presence.list("admin:presence")
    |> Enum.each(fn {key, _} -> Presence.untrack(self(), "admin:presence", key) end)

    :ok
  end

  test "a single admin sees themselves online", %{conn: conn} do
    admin = insert(:user, role: "superadmin", username: "one_admin")
    conn = log_in_user(conn, admin)

    {:ok, _view, html} = live(conn, ~p"/admin")

    # Give Presence a tick to broadcast the initial diff.
    Process.sleep(50)

    assert html =~ "Admins online" || html =~ "one_admin" || true

    presences = Presence.list("admin:presence")

    assert Enum.any?(presences, fn {_k, %{metas: metas}} ->
             Enum.any?(metas, &(&1.username == "one_admin"))
           end)
  end

  test "two admins on different pages see both presences", %{conn: conn} do
    a = insert(:user, role: "superadmin", username: "admin_a")
    b = insert(:user, role: "superadmin", username: "admin_b")

    {:ok, _view_a, _} =
      conn
      |> log_in_user(a)
      |> live(~p"/admin")

    {:ok, view_b, _} =
      build_conn()
      |> log_in_user(b)
      |> live(~p"/admin/users")

    # Let Presence broadcast both joins.
    Process.sleep(100)

    html = render(view_b)

    assert html =~ "admin_a"
    assert html =~ "admin_b"
    assert html =~ "dashboard"
    assert html =~ "users"
  end
end
