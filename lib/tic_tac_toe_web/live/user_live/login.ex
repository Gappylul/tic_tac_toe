defmodule TicTacToeWeb.UserLive.Login do
  use TicTacToeWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash = {@flash}>
    <div class="mx-auto max-w-sm">
      <.header>
        Log in
        <:subtitle>
          Don't have an account?
          <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
            Sign up for an account now.
          </.link>
        </:subtitle>
      </.header>

      <.form
        :let={f}
        for={@form}
        id="login_form"
        action={~p"/users/log-in"}
        phx-submit="submit"
        phx-trigger-action={@trigger_submit}
      >
        <.input
          field={f[:email]}
          type="email"
          label="Email"
          autocomplete="email"
          required
          phx-mounted={JS.focus()}
        />
        <.input
          field={@form[:password]}
          type="password"
          label="Password"
          autocomplete="current-password"
          required
        />

        <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
          Log in and stay logged in →
        </.button>

        <.button class="btn btn-primary btn-soft w-full mt-2">
          Log in only this time
        </.button>
      </.form>
    </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
