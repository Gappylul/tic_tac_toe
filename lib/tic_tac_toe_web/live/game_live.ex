defmodule TicTacToeWeb.GameLive do
  use TicTacToeWeb, :live_view
  alias TicTacToe.Games
  alias TicTacToeWeb.Presence

  @impl true
  def mount(%{"id" => game_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TicTacToe.PubSub, "game:#{game_id}")
      Phoenix.PubSub.subscribe(TicTacToe.PubSub, "presence:#{game_id}")
      track_presence(socket, game_id)
    end

    game = Games.get_game_by_game_id(game_id)

    socket =
      if game do
        user_id = socket.assigns.current_scope.user.id

        socket =
          if Games.get_player_symbol(game, user_id) == nil do
            case Games.join_game(game, user_id) do
              {:ok, updated_game} ->
                Games.broadcast_game_update(game_id)
                assign(socket, game: updated_game)

              {:error, _} ->
                assign(socket, game: game)
            end
          else
            assign(socket, game: game)
          end

        player_symbol = Games.get_player_symbol(socket.assigns.game, user_id)

        socket
        |> assign(:player_symbol, player_symbol)
        |> assign(:game_url, url(~p"/game/#{game_id}"))
        |> assign(:game_id, game_id)
      else
        put_flash(socket, :error, "Game not found")
        |> push_navigate(to: ~p"/")
      end

    {:ok, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    if Map.has_key?(socket.assigns, :game_id) do
      game_id = socket.assigns.game_id

      # Broadcast that player left
      Games.broadcast_player_left(game_id)

      # Schedule game deletion check
      spawn(fn ->
        :timer.sleep(2000)
        check_and_delete_game(game_id)
      end)
    end

    :ok
  end

  @impl true
  def handle_event("make_move", %{"position" => position}, socket) do
    user_id = socket.assigns.current_scope.user.id
    game = socket.assigns.game

    case Games.make_move(game, String.to_integer(position), user_id) do
      {:ok, updated_game} ->
        Games.broadcast_game_update(game.game_id)
        {:noreply, assign(socket, game: updated_game)}

      {:error, reason} ->
        message =
          case reason do
            :not_your_turn -> "It's not your turn!"
            :position_taken -> "This position is already taken!"
            :not_a_player -> "You're not in this game!"
            :game_not_ready -> "Game is not ready yet!"
            _ -> "Invalid move"
          end

        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("reset_game", _params, socket) do
    game = socket.assigns.game

    case Games.reset_game(game) do
      {:ok, updated_game} ->
        Games.broadcast_game_update(game.game_id)
        {:noreply, assign(socket, game: updated_game)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reset game")}
    end
  end

  @impl true
  def handle_event("copy_link", _params, socket) do
    {:noreply, put_flash(socket, :info, "Link copied to clipboard!")}
  end

  @impl true
  def handle_info(:game_updated, socket) do
    game = Games.get_game_by_game_id(socket.assigns.game.game_id)
    {:noreply, assign(socket, game: game)}
  end

  @impl true
  def handle_info(:player_left, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    game_id = socket.assigns.game_id
    presences = get_presence_count(game_id)

    # If no one is present, schedule game deletion
    if presences == 0 do
      Process.send_after(self(), :check_delete_game, 1000)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:check_delete_game, socket) do
    game_id = socket.assigns.game_id
    check_and_delete_game(game_id)
    {:noreply, socket}
  end

  defp track_presence(socket, game_id) do
    user_id = socket.assigns.current_scope.user.id

    {:ok, _} =
      Presence.track(
        self(),
        "presence:#{game_id}",
        to_string(user_id),
        %{}
      )
  end

  defp get_presence_count(game_id) do
    Presence.list("presence:#{game_id}")
    |> Map.keys()
    |> length()
  end

  defp check_and_delete_game(game_id) do
    presences = get_presence_count(game_id)

    if presences == 0 do
      Games.delete_game_by_id(game_id)
    end
  end

  defp get_cell_value(board, position) do
    Map.get(board, to_string(position))
  end

  defp player_name(game, symbol) do
    case symbol do
      "x" -> if game.player_x_id, do: "Player X", else: "Waiting..."
      "o" -> if game.player_o_id, do: "Player O", else: "Waiting..."
      _ -> ""
    end
  end
end
