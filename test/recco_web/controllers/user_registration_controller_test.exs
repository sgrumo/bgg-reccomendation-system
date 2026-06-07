defmodule ReccoWeb.UserRegistrationControllerTest do
  use ReccoWeb.ConnCase, async: true

  import Swoosh.TestAssertions

  describe "GET /register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/register")
      response = html_response(conn, 200)
      assert response =~ "Create an account"
    end
  end

  describe "POST /register" do
    test "creates user, logs in, and redirects to onboarding", %{conn: conn} do
      conn =
        post(conn, ~p"/register", %{
          "user" => %{
            "email" => "new@example.com",
            "username" => "newuser",
            "password" => "valid_password123"
          }
        })

      assert redirected_to(conn) == ~p"/onboarding"
      assert get_session(conn, :user_token)
    end

    test "dispatches the confirmation email on successful signup", %{conn: conn} do
      post(conn, ~p"/register", %{
        "user" => %{
          "email" => "confirmable@example.com",
          "username" => "confirmable",
          "password" => "valid_password123"
        }
      })

      assert_email_sent(fn email ->
        assert email.to == [{"", "confirmable@example.com"}]
        assert email.subject == "Confirm your email"
      end)
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
