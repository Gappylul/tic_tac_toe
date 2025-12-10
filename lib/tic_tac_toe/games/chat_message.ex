defmodule TicTacToe.Games.ChatMessage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_messages" do
    field :message, :string
    field :message_type, :string, default: "text"
    field :is_spectator, :boolean, default: false
    field :game_id, :id
    field :user_id, :id

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(chat_message, attrs) do
    chat_message
    |> cast(attrs, [:game_id, :user_id, :message, :message_type, :is_spectator])
    |> validate_required([:game_id, :message, :message_type])
    |> validate_inclusion(:message_type, ["text", "emoji", "quick"])
  end
end
