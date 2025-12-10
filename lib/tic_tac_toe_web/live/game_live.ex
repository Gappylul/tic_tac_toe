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
                Games.broadcast_spectator_update(game_id)
                assign(socket, game: updated_game)

              {:error, _} ->
                assign(socket, game: game)
            end
          else
            assign(socket, game: game)
          end

        player_symbol = Games.get_player_symbol(socket.assigns.game, user_id)
        chat_messages = Games.list_chat_messages(socket.assigns.game.id)
        spectator_count = get_spectator_count(game_id, socket.assigns.game)

        socket =
          socket
          |> assign(:player_symbol, player_symbol)
          |> assign(:game_url, url(~p"/game/#{game_id}"))
          |> assign(:game_id, game_id)
          |> assign(:chat_messages, chat_messages)
          |> assign(:chat_input, "")
          |> assign(:spectator_count, spectator_count)
          |> assign(:show_quick_chat, false)
          |> assign(:current_time, DateTime.utc_now())

        # Start timer for timed games
        socket =
          if game.game_mode in ["timed", "blitz"] and game.status == "playing" do
            schedule_timer_tick(socket)
          else
            socket
          end

        socket
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

      Games.broadcast_player_left(game_id)
      Games.broadcast_spectator_update(game_id)

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
        {:noreply, assign(socket, game: updated_game) |> schedule_timer_tick()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reset game")}
    end
  end

  @impl true
  def handle_event("copy_link", _params, socket) do
    {:noreply, put_flash(socket, :info, "Link copied to clipboard!")}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    if String.trim(message) != "" do
      user_id = socket.assigns.current_scope.user.id
      game = socket.assigns.game
      is_spectator = socket.assigns.player_symbol == nil

      {:ok, chat_message} =
        Games.create_chat_message(%{
          game_id: game.id,
          user_id: user_id,
          message: String.trim(message),
          message_type: "text",
          is_spectator: is_spectator
        })

      Games.broadcast_chat_message(game.game_id, chat_message)
      {:noreply, assign(socket, chat_input: "")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_quick_chat", %{"message" => message}, socket) do
    user_id = socket.assigns.current_scope.user.id
    game = socket.assigns.game
    is_spectator = socket.assigns.player_symbol == nil

    {:ok, chat_message} =
      Games.create_chat_message(%{
        game_id: game.id,
        user_id: user_id,
        message: message,
        message_type: "quick",
        is_spectator: is_spectator
      })

    Games.broadcast_chat_message(game.game_id, chat_message)
    {:noreply, assign(socket, show_quick_chat: false)}
  end

  @impl true
  def handle_event("send_emoji", %{"emoji" => emoji}, socket) do
    user_id = socket.assigns.current_scope.user.id
    game = socket.assigns.game
    is_spectator = socket.assigns.player_symbol == nil

    {:ok, chat_message} =
      Games.create_chat_message(%{
        game_id: game.id,
        user_id: user_id,
        message: emoji,
        message_type: "emoji",
        is_spectator: is_spectator
      })

    Games.broadcast_chat_message(game.game_id, chat_message)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_quick_chat", _params, socket) do
    {:noreply, assign(socket, show_quick_chat: !socket.assigns.show_quick_chat)}
  end

  def handle_event("update_chat_input", %{} = params, socket) do
    value =
      params["value"] ||
        params["message"] ||
        ""

    {:noreply, assign(socket, chat_input: value)}
  end

  @impl true
  def handle_info(:game_updated, socket) do
    game = Games.get_game_by_game_id(socket.assigns.game.game_id)

    socket =
      socket
      |> assign(game: game)
      |> maybe_schedule_timer(game)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:player_left, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:chat_message, message}, socket) do
    chat_messages = socket.assigns.chat_messages ++ [message]
    {:noreply, assign(socket, chat_messages: chat_messages)}
  end

  @impl true
  def handle_info(:spectator_update, socket) do
    spectator_count = get_spectator_count(socket.assigns.game_id, socket.assigns.game)
    {:noreply, assign(socket, spectator_count: spectator_count)}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    game_id = socket.assigns.game_id
    presences = get_presence_count(game_id)
    spectator_count = get_spectator_count(game_id, socket.assigns.game)

    socket = assign(socket, spectator_count: spectator_count)

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

  @impl true
  def handle_info(:timer_tick, socket) do
    game = socket.assigns.game

    if game.game_mode in ["timed", "blitz"] and game.status == "playing" do
      # Check if time expired
      now = DateTime.utc_now()
      player_symbol = game.current_player

      time_left =
        if player_symbol == "x" do
          game.player_x_time_left
        else
          game.player_o_time_left
        end

      if game.last_move_at do
        elapsed = DateTime.diff(now, game.last_move_at, :second)
        remaining = time_left - elapsed

        if remaining <= 0 do
          # Time expired, end game
          winner = if player_symbol == "x", do: "o", else: "x"
          {:ok, updated_game} = Games.update_game(game, %{winner: winner, status: "finished"})
          Games.broadcast_game_update(game.game_id)
          {:noreply, assign(socket, game: updated_game)}
        else
          schedule_timer_tick(socket)
          {:noreply, assign(socket, current_time: now)}
        end
      else
        schedule_timer_tick(socket)
        {:noreply, assign(socket, current_time: now)}
      end
    else
      {:noreply, socket}
    end
  end

  defp schedule_timer_tick(socket) do
    Process.send_after(self(), :timer_tick, 1000)
    socket
  end

  defp maybe_schedule_timer(socket, game) do
    if game.game_mode in ["timed", "blitz"] and game.status == "playing" do
      schedule_timer_tick(socket)
    else
      socket
    end
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

  defp get_spectator_count(game_id, game) do
    presences = Presence.list("presence:#{game_id}") |> Map.keys()

    player_ids =
      [
        to_string(game.player_x_id),
        to_string(game.player_o_id)
      ]
      |> Enum.filter(&(&1 != ""))

    Enum.count(presences, fn user_id -> user_id not in player_ids end)
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

  defp format_time(nil), do: "--:--"
  defp format_time(seconds) when seconds < 0, do: "00:00"

  defp format_time(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(secs), 2, "0")}"
  end

  defp get_time_left(game, player_symbol) do
    if game.last_move_at && game.current_player == player_symbol do
      now = DateTime.utc_now()
      elapsed = DateTime.diff(now, game.last_move_at, :second)

      time_left =
        if player_symbol == "x" do
          game.player_x_time_left
        else
          game.player_o_time_left
        end

      max(0, time_left - elapsed)
    else
      if player_symbol == "x" do
        game.player_x_time_left
      else
        game.player_o_time_left
      end
    end
  end

  defp format_message_time(inserted_at) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, inserted_at, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      true -> "#{div(diff, 3600)}h ago"
    end
  end

  defp get_message_style(message_type) do
    case message_type do
      "quick" -> "bg-purple-500/20 border-purple-500/50 text-purple-200"
      "emoji" -> "text-2xl"
      _ -> "bg-white/10"
    end
  end
end
