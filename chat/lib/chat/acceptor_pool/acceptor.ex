#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule Chat.AcceptorPool.Acceptor do
  use Task, restart: :transient

  alias Chat.AcceptorPool.ConnectionSupervisor

  require Logger

  @spec start_link(:gen_tcp.socket()) :: {:ok, pid()}
  def start_link(listen_socket) do
    Task.start_link(__MODULE__, :__accept_loop__, [listen_socket])
  end

  @doc false
  def __accept_loop__(listen_socket) do
    case :gen_tcp.accept(listen_socket, 2_000) do
      {:ok, socket} ->
        {:ok, pid} = ConnectionSupervisor.start_connection(socket)
        :ok = :gen_tcp.controlling_process(socket, pid)
        __accept_loop__(listen_socket)

      {:error, :timeout} ->
        __accept_loop__(listen_socket)

      {:error, reason} ->
        Logger.error("Error in TCP accept: #{:inet.format_error(reason)}")
        :error
    end
  end
end
