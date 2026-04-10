defmodule ReccoWeb.UserRegistrationControllerTest do
  use ReccoWeb.ConnCase, async: true

  describe "GET /register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/register")
      response = html_response(conn, 200)
      assert response =~ "Create an account"
    end
  end

  describe "POST /register" do
    test "creates user and logs in", %{conn: conn} do
      conn =
        post(conn, ~p"/register", %{
          "user" => %{
            "email" => "new@example.com",
            "username" => "newuser",
            "password" => "valid_password123"
          }
        })

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_token)
    end

    test "shows errors for invalid data", %{conn: conn} do
      conn =
        post(conn, ~p"/register", %{
          "user" => %{"email" => "", "username" => "", "password" => ""}
        })

      response = html_response(conn, 200)
      assert response =~ "Create an account"
    end
  end
end
