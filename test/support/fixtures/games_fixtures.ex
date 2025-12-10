defmodule TicTacToe.GamesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TicTacToe.Games` context.
  """

  @doc """
  Generate a unique game game_id.
  """
  def unique_game_game_id, do: "some game_id#{System.unique_integer([:positive])}"
end
