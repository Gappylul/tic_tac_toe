defmodule TicTacToe.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias TicTacToe.Accounts
  alias TicTacToe.Repo
  alias TicTacToe.Games.Game
  alias TicTacToe.Games.ChatMessage

  def list_games do
    Repo.all(Game)
  end

  def get_game!(id), do: Repo.get!(Game, id)

  def get_game_by_game_id(game_id) do
    Repo.get_by(Game, game_id: game_id)
  end

  def create_game(attrs \\ %{}) do
    %Game{}
    |> Game.changeset(attrs)
    |> Repo.insert()
  end

  def update_game(%Game{} = game, attrs) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  def delete_game(%Game{} = game) do
    Repo.delete(game)
  end

  def change_game(%Game{} = game, attrs \\ %{}) do
    Game.changeset(game, attrs)
  end

  # Game logic functions.

  def new_game_id do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 8)
  end

  def create_new_game(user_id, game_mode \\ "normal") do
    game_id = new_game_id()

    {time_per_move, total_time} =
      case game_mode do
        "blitz" -> {10, 300}
        "timed" -> {30, 900}
        "normal" -> {nil, nil}
        _ -> {nil, nil}
      end

    create_game(%{
      game_id: game_id,
      board: %{
        "0" => nil,
        "1" => nil,
        "2" => nil,
        "3" => nil,
        "4" => nil,
        "5" => nil,
        "6" => nil,
        "7" => nil,
        "8" => nil
      },
      current_player: "x",
      status: "waiting",
      player_x_id: user_id,
      rematch_count: 0,
      game_mode: game_mode,
      time_per_move: time_per_move,
      player_x_time_left: total_time,
      player_o_time_left: total_time
    })
  end

  def join_game(%Game{} = game, user_id) do
    cond do
      game.player_o_id == nil and game.player_x_id != user_id ->
        update_game(game, %{player_o_id: user_id, status: "playing"})

      true ->
        {:ok, game}
    end
  end

  def get_player_symbol(%Game{} = game, user_id) do
    cond do
      game.player_x_id == user_id -> "x"
      game.player_o_id == user_id -> "o"
      true -> nil
    end
  end

  def make_move(%Game{status: "playing"} = game, position, user_id) do
    player_symbol = get_player_symbol(game, user_id)
    now = DateTime.utc_now()

    cond do
      player_symbol == nil ->
        {:error, :not_a_player}

      game.current_player != player_symbol ->
        {:error, :not_your_turn}

      check_time_expired(game, player_symbol, now) ->
        winner = if player_symbol == "x", do: "o", else: "x"
        winner_id = if winner == "x", do: game.player_x_id, else: game.player_o_id
        Accounts.increment_user_wins(winner_id)
        update_game(game, %{winner: winner, status: "finished"})

      Map.get(game.board, to_string(position)) != nil ->
        {:error, :position_taken}

      true ->
        new_board = Map.put(game.board, to_string(position), player_symbol)
        updated_game = update_time_left(game, player_symbol, now)

        case check_winner(new_board) do
          nil ->
            next_player = if player_symbol == "x", do: "o", else: "x"

            update_game(updated_game, %{
              board: new_board,
              current_player: next_player,
              last_move_at: now
            })

          winner ->
            result =
              update_game(updated_game, %{
                board: new_board,
                winner: winner,
                status: "finished"
              })

            if winner != "draw" do
              winner_id = if winner == "x", do: game.player_x_id, else: game.player_o_id
              Accounts.increment_user_wins(winner_id)
            end

            result
        end
    end
  end

  def make_move(%Game{} = _game, _position, _user_id) do
    {:error, :game_not_ready}
  end

  def reset_game(%Game{} = game) do
    {_time_per_move, total_time} =
      case game.game_mode do
        "blitz" -> {10, 300}
        "timed" -> {30, 900}
        "normal" -> {nil, nil}
        _ -> {nil, nil}
      end

    update_game(game, %{
      board: %{
        "0" => nil,
        "1" => nil,
        "2" => nil,
        "3" => nil,
        "4" => nil,
        "5" => nil,
        "6" => nil,
        "7" => nil,
        "8" => nil
      },
      current_player: "x",
      winner: nil,
      status: if(game.player_x_id && game.player_o_id, do: "playing", else: "waiting"),
      rematch_count: game.rematch_count + 1,
      player_x_time_left: total_time,
      player_o_time_left: total_time,
      last_move_at: nil
    })
  end

  defp check_time_expired(game, player_symbol, now) do
    if game.game_mode in ["timed", "blitz"] and game.last_move_at do
      time_left =
        if player_symbol == "x", do: game.player_x_time_left, else: game.player_o_time_left

      if time_left do
        elapsed = DateTime.diff(now, game.last_move_at, :second)
        time_left - elapsed <= 0
      else
        false
      end
    else
      false
    end
  end

  defp update_time_left(game, player_symbol, now) do
    if game.game_mode in ["timed", "blitz"] and game.last_move_at do
      elapsed = DateTime.diff(now, game.last_move_at, :second)

      if player_symbol == "x" do
        new_time = max(0, game.player_x_time_left - elapsed)
        %{game | player_x_time_left: new_time}
      else
        new_time = max(0, game.player_o_time_left - elapsed)
        %{game | player_o_time_left: new_time}
      end
    else
      game
    end
  end

  defp check_winner(board) do
    winning_combinations = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6]
    ]

    winner =
      Enum.find_value(winning_combinations, fn [a, b, c] ->
        pos_a = Map.get(board, to_string(a))
        pos_b = Map.get(board, to_string(b))
        pos_c = Map.get(board, to_string(c))

        case {pos_a, pos_b, pos_c} do
          {player, player, player} when player != nil -> player
          _ -> nil
        end
      end)

    cond do
      winner -> winner
      Enum.all?(0..8, fn i -> Map.get(board, to_string(i)) != nil end) -> "draw"
      true -> nil
    end
  end

  def broadcast_game_update(game_id) do
    Phoenix.PubSub.broadcast(
      TicTacToe.PubSub,
      "game:#{game_id}",
      :game_updated
    )
  end

  def broadcast_player_left(game_id) do
    Phoenix.PubSub.broadcast(
      TicTacToe.PubSub,
      "game:#{game_id}",
      :player_left
    )
  end

  def delete_game_by_id(game_id) do
    case get_game_by_game_id(game_id) do
      nil -> {:error, :not_found}
      game -> delete_game(game)
    end
  end

  # Chat functions

  def create_chat_message(attrs) do
    %ChatMessage{}
    |> ChatMessage.changeset(attrs)
    |> Repo.insert()
  end

  def list_chat_messages(game_id) do
    from(m in ChatMessage,
      where: m.game_id == ^game_id,
      order_by: [asc: m.inserted_at],
      limit: 100,
      preload: []
    )
    |> Repo.all()
  end

  def get_user_email(user_id) do
    case Accounts.get_user(user_id) do
      nil -> "unknown"
      user -> user.email
    end
  end

  def broadcast_chat_message(game_id, message) do
    Phoenix.PubSub.broadcast(
      TicTacToe.PubSub,
      "game:#{game_id}",
      {:chat_message, message}
    )
  end

  def broadcast_spectator_update(game_id) do
    Phoenix.PubSub.broadcast(
      TicTacToe.PubSub,
      "game:#{game_id}",
      :spectator_update
    )
  end
end
