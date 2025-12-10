defmodule TicTacToe.Repo.Migrations.AddRematchCountToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :rematch_count, :integer, default: 0, null: false
    end
  end
end
