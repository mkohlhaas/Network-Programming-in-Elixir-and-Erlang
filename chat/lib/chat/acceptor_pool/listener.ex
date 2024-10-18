#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule Chat.AcceptorPool.Listener do
  use GenServer, restart: :transient

  alias Chat.AcceptorPool.AcceptorSupervisor

  require Logger

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link({options, supervisor}) do
    GenServer.start_link(__MODULE__, {options, supervisor})
  end

  @impl true
  def init({options, supervisor}) do
    port = Keyword.fetch!(options, :port)

    listen_options = [
      :binary,
      active: :once,
      exit_on_close: false,
      reuseaddr: true
    ]

    case :gen_tcp.listen(port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Started pooled chat server on port #{port}")
        state = {listen_socket, supervisor}
        {:ok, state, {:continue, :start_acceptor_pool}} 

      {:error, reason} ->
        {:stop, {:listen_error, reason}}
    end
  end

  @impl true
  def handle_continue(:start_acceptor_pool, {listen_socket, supervisor}) do 
    spec = {AcceptorSupervisor, listen_socket: listen_socket}
    {:ok, _} = Supervisor.start_child(supervisor, spec) 

    {:noreply, {listen_socket, supervisor}}
  end
end
