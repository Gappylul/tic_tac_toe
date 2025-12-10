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
    field :game_mode, :string, default: "normal"
    field :time_per_move, :integer
    field :player_x_time_left, :integer
    field :player_o_time_left, :integer
    field :last_move_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [
      :game_id,
      :board,
      :current_player,
      :winner,
      :status,
      :player_x_id,
      :player_o_id,
      :rematch_count,
      :game_mode,
      :time_per_move,
      :player_x_time_left,
      :player_o_time_left,
      :last_move_at
    ])
    |> validate_required([:game_id, :board, :current_player, :status])
    |> unique_constraint(:game_id)
  end
end
