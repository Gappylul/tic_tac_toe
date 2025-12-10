defmodule TicTacToe.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :game_id, :string
      add :board, :map
      add :current_player, :string
      add :winner, :string
      add :status, :string
      add :player_x_id, references(:users, on_delete: :nothing)
      add :player_o_id, references(:users, on_delete: :nothing)
      add :user_id, references(:users, type: :id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:games, [:user_id])

    create unique_index(:games, [:game_id])
    create index(:games, [:player_x_id])
    create index(:games, [:player_o_id])
  end
end
