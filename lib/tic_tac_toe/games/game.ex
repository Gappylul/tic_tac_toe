defmodule TicTacToe.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  schema "games" do
    field :game_id, :string
    field :board, :map
    field :current_player, :string
    field :winner, :string
    field :status, :string
    field :player_x_id, :id
    field :player_o_id, :id
    field :rematch_count, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:game_id, :board, :current_player, :winner, :status, :player_x_id, :player_o_id, :rematch_count])
    |> validate_required([:game_id, :board, :current_player, :status])
    |> unique_constraint(:game_id)
  end
end
