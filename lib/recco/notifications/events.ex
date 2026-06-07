defmodule Recco.Notifications.Events do
  @moduledoc """
  Builds Discord notification payloads for domain events and dispatches them
  through `Recco.Notifications.Discord`.
  """

  alias Recco.Accounts.User
  alias Recco.Notifications.Discord
  alias Recco.Prototypes.Prototype

  @user_color 0x22C55E
  @prototype_color 0x3B82F6

  @spec user_registered(User.t()) :: :ok
  def user_registered(%User{username: username}) do
    Discord.notify(%{
      embeds: [
        %{
          title: "New user registered",
          description: "**#{username}** just joined Recco",
          color: @user_color
        }
      ]
    })
  end

  @spec prototype_posted(Prototype.t()) :: :ok
  def prototype_posted(%Prototype{} = prototype) do
    Discord.notify(%{
      embeds: [
        %{
          title: "New prototype posted",
          description: "**#{prototype.title}** by **#{author(prototype)}**",
          color: @prototype_color,
          fields: [
            %{
              name: "Players",
              value: "#{prototype.min_players}–#{prototype.max_players}",
              inline: true
            },
            %{
              name: "Playtime",
              value: "#{prototype.min_playtime}–#{prototype.max_playtime} min",
              inline: true
            }
          ]
        }
      ]
    })
  end

  defp author(%Prototype{user: %User{username: username}}) when is_binary(username), do: username
  defp author(_), do: "unknown"
end
