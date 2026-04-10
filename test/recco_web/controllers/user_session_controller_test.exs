defmodule ReccoWeb.UserSessionControllerTest do
  use ReccoWeb.ConnCase, async: true

  describe "GET /login" do
    test "renders login page", %{conn: conn} do
      conn = get(conn, ~p"/login")
      response = html_response(conn, 200)
      assert response =~ "Sign in"
    end
  end

  describe "POST /login" do
    test "logs in with valid credentials", %{conn: conn} do
      insert(:user, email: "login@example.com")

      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => "login@example.com", "password" => "valid_password123"}
        })

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_token)
    end

    test "shows error with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => "nope@example.com", "password" => "wrong"}
        })

      response = html_response(conn, 200)
      assert response =~ "Invalid email or password"
    end
  end

  describe "DELETE /logout" do
    test "logs out user", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)

      conn = delete(conn, ~p"/logout")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
    end
  end
end
