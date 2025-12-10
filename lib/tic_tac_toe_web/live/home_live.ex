defmodule TicTacToeWeb.HomeLive do
  use TicTacToeWeb, :live_view
  alias TicTacToe.{Games, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    leaderboard = Accounts.get_leaderboard(10)

    socket =
      socket
      |> assign(:leaderboard, leaderboard)

    {:ok, socket}
  end

  @impl true
  def handle_event("create_game", _params, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Games.create_new_game(user_id) do
      {:ok, game} ->
        {:noreply, push_navigate(socket, to: ~p"/game/#{game.game_id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create game")}
    end
  end

  @impl true
  def handle_event("join_game", %{"game_id" => game_id}, socket) do
    game = Games.get_game_by_game_id(game_id)

    if game do
      {:noreply, push_navigate(socket, to: ~p"/game/#{game_id}")}
    else
      {:noreply, put_flash(socket, :error, "Game not found")}
    end
  end
end
