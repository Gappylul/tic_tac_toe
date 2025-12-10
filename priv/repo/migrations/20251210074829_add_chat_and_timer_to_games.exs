defmodule TicTacToe.Repo.Migrations.AddChatAndTimerToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :game_mode, :string, default: "normal", null: false
      add :time_per_move, :integer
      add :player_x_time_left, :integer
      add :player_o_time_left, :integer
      add :last_move_at, :utc_datetime
    end

    create table(:chat_messages) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)
      add :message, :text, null: false
      add :message_type, :string, default: "text", null: false
      add :is_spectator, :boolean, default: false, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:chat_messages, [:game_id])
    create index(:chat_messages, [:user_id])
  end
end
