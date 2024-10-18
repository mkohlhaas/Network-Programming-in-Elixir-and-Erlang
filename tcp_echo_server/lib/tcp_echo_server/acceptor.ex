#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule TCPEchoServer.Acceptor do
  use GenServer # (1)

  require Logger

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @impl true
  def init(options) do
    port = Keyword.fetch!(options, :port)

    listen_options = [ # (2)
      :binary,
      active: true,
      exit_on_close: false,
      reuseaddr: true,
      backlog: 25
    ]

    case :gen_tcp.listen(port, listen_options) do # (3)
      {:ok, listen_socket} ->
        Logger.info("Started TCP server on port #{port}")
        send(self(), :accept) # (4)
        {:ok, listen_socket} # (5)

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:accept, listen_socket) do # (6)
    case :gen_tcp.accept(listen_socket, 2_000) do # (7)
      {:ok, socket} ->
        {:ok, pid} = TCPEchoServer.Connection.start_link(socket) # (8)
        :ok = :gen_tcp.controlling_process(socket, pid) # (9)
        send(self(), :accept) # (10)
        {:noreply, listen_socket}


      {:error, :timeout} -> # (11)
        send(self(), :accept)
        {:noreply, listen_socket}

      {:error, reason} -> # (12)
        {:stop, reason, listen_socket}
    end
  end
end
