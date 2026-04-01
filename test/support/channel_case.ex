defmodule ReccoWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import ReccoWeb.ChannelCase

      @endpoint ReccoWeb.Endpoint
    end
  end

  setup tags do
    Recco.DataCase.setup_sandbox(tags)
    :ok
  end
end
