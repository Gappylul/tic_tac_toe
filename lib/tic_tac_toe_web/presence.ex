defmodule TicTacToeWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.
  """
  use Phoenix.Presence,
    otp_app: :tic_tac_toe,
    pubsub_server: TicTacToe.PubSub
end
