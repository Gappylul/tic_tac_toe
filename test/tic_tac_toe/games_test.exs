defmodule TicTacToe.GamesTest do
  use TicTacToe.DataCase

  alias TicTacToe.Games

  describe "games" do
    alias TicTacToe.Games.Game

    import TicTacToe.AccountsFixtures, only: [user_scope_fixture: 0]
    import TicTacToe.GamesFixtures

    @invalid_attrs %{status: nil, game_id: nil, board: nil, current_player: nil, winner: nil}

    test "list_games/1 returns all scoped games" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      game = game_fixture(scope)
      other_game = game_fixture(other_scope)
      assert Games.list_games(scope) == [game]
      assert Games.list_games(other_scope) == [other_game]
    end

    test "get_game!/2 returns the game with given id" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      other_scope = user_scope_fixture()
      assert Games.get_game!(scope, game.id) == game
      assert_raise Ecto.NoResultsError, fn -> Games.get_game!(other_scope, game.id) end
    end

    test "create_game/2 with valid data creates a game" do
      valid_attrs = %{status: "some status", game_id: "some game_id", board: %{}, current_player: "some current_player", winner: "some winner"}
      scope = user_scope_fixture()

      assert {:ok, %Game{} = game} = Games.create_game(scope, valid_attrs)
      assert game.status == "some status"
      assert game.game_id == "some game_id"
      assert game.board == %{}
      assert game.current_player == "some current_player"
      assert game.winner == "some winner"
      assert game.user_id == scope.user.id
    end

    test "create_game/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Games.create_game(scope, @invalid_attrs)
    end

    test "update_game/3 with valid data updates the game" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      update_attrs = %{status: "some updated status", game_id: "some updated game_id", board: %{}, current_player: "some updated current_player", winner: "some updated winner"}

      assert {:ok, %Game{} = game} = Games.update_game(scope, game, update_attrs)
      assert game.status == "some updated status"
      assert game.game_id == "some updated game_id"
      assert game.board == %{}
      assert game.current_player == "some updated current_player"
      assert game.winner == "some updated winner"
    end

    test "update_game/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      game = game_fixture(scope)

      assert_raise MatchError, fn ->
        Games.update_game(other_scope, game, %{})
      end
    end

    test "update_game/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Games.update_game(scope, game, @invalid_attrs)
      assert game == Games.get_game!(scope, game.id)
    end

    test "delete_game/2 deletes the game" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      assert {:ok, %Game{}} = Games.delete_game(scope, game)
      assert_raise Ecto.NoResultsError, fn -> Games.get_game!(scope, game.id) end
    end

    test "delete_game/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      game = game_fixture(scope)
      assert_raise MatchError, fn -> Games.delete_game(other_scope, game) end
    end

    test "change_game/2 returns a game changeset" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      assert %Ecto.Changeset{} = Games.change_game(scope, game)
    end
  end
end
