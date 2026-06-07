defmodule Recco.Accounts.UserNotifierTest do
  use Recco.DataCase, async: true

  import Swoosh.TestAssertions

  alias Recco.Accounts.UserNotifier

  describe "deliver_reset_password_instructions/2" do
    test "sends an email to the user with the given url" do
      user = insert(:user, email: "owner@example.com", username: "owner")
      url = "https://example.test/reset-password/abc"

      assert {:ok, _meta} = UserNotifier.deliver_reset_password_instructions(user, url)

      assert_email_sent(fn email ->
        assert email.to == [{"", "owner@example.com"}]
        assert email.from == {"Recco", "onboarding@resend.dev"}
        assert email.subject == "Reset your password"
        assert email.text_body =~ "Hi owner"
        assert email.text_body =~ url
      end)
    end
  end

  describe "deliver_confirmation_instructions/2" do
    test "sends a confirmation email to the user with the given url" do
      user = insert(:user, email: "newbie@example.com", username: "newbie")
      url = "https://example.test/confirm/abc"

      assert {:ok, _meta} = UserNotifier.deliver_confirmation_instructions(user, url)

      assert_email_sent(fn email ->
        assert email.to == [{"", "newbie@example.com"}]
        assert email.from == {"Recco", "onboarding@resend.dev"}
        assert email.subject == "Confirm your email"
        assert email.text_body =~ "Hi newbie"
        assert email.text_body =~ url
      end)
    end
  end
end
