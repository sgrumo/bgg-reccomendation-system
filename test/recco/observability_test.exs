defmodule Recco.ObservabilityTest do
  @moduledoc """
  Verifies that telemetry spans we added actually fire with expected
  metadata. Rather than asserting on Logger output (brittle), we attach a
  self-handler and match on the event payload.
  """
  use Recco.DataCase, async: false

  alias Recco.Accounts
  alias Recco.Observability.Counters

  setup do
    # Drain counters before each test so we can assert deltas.
    Counters.snapshot_and_reset()

    test_pid = self()
    ref = make_ref()

    handler_id = {__MODULE__, ref}

    :telemetry.attach_many(
      handler_id,
      [
        [:recco, :auth, :login, :stop],
        [:recco, :auth, :bcrypt, :stop],
        [:recco, :auth, :register, :stop]
      ],
      fn event, measurements, meta, _ ->
        send(test_pid, {:telemetry_event, event, measurements, meta})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    :ok
  end

  test "login failure fires telemetry and bumps the failed-login counter" do
    assert {:error, :unauthorized} =
             Accounts.authenticate_user_by_email("ghost@example.com", "nope")

    assert_receive {:telemetry_event, [:recco, :auth, :login, :stop], _measurements,
                    %{result: :invalid_credentials}}

    assert_receive {:telemetry_event, [:recco, :auth, :bcrypt, :stop], _measurements,
                    %{path: :no_user_verify}}

    assert %{auth_failed: 1} = Counters.snapshot()
  end

  test "register telemetry fires on failure" do
    assert {:error, :unprocessable_entity, _} = Accounts.register_user(%{})

    assert_receive {:telemetry_event, [:recco, :auth, :register, :stop], _measurements,
                    %{result: :invalid}}
  end
end
