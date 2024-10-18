#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule XStats.Reporter do
  @moduledoc """
  A process for reporting metrics to a collector server.
  """

  @mtu 512


  use GenServer

  require Logger

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @doc """
  Increments the given counter by the given value.
  """
  @spec increment_counter(GenServer.server(), String.t(), number()) :: :ok
  def increment_counter(server, name, value) do
    GenServer.cast(server, {:send_metric, {:counter, name, value}})
  end

  @doc """
  Sets the given gauge to the given value.
  """
  @spec set_gauge(GenServer.server(), String.t(), number()) :: :ok
  def set_gauge(server, name, value) do
    GenServer.cast(server, {:send_metric, {:gauge, name, value}})
  end


  ## Callbacks

  defstruct [:socket, :dest_port]

  @impl true
  def init(options) do
    dest_port = Keyword.fetch!(options, :dest_port)

    case :gen_udp.open(0, [:binary]) do
      {:ok, socket} ->
        state = %__MODULE__{socket: socket, dest_port: dest_port}
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end


  @impl true
  def handle_cast({:send_metric, metric}, %__MODULE__{} = state) do
    iodata = XStats.Protocol.encode_metric(metric)

    if IO.iodata_length(iodata) > @mtu do
      Logger.error("Metric too large to send: #{inspect(metric)}")
    else
      _ = :gen_udp.send(state.socket, ~c"localhost", state.dest_port, iodata)
    end

    {:noreply, state}
  end

  # This version of handle_cast/2 is here only so that the source code
  # can be showed in the book. It doesn't take MTU into consideration,
  # so we're not really using it for the real-world implementation.
  # The :rand.uniform/0 here is just a trick to make sure the "if" is
  # never true (but doesn't warn at compile time), and the handle_cast/2
  # code is never compiled or executed.
  if :rand.uniform() < 0 do
    @impl true
    def handle_cast({:send_metric, metric}, %__MODULE__{} = state) do
      iodata = XStats.Protocol.encode_metric(metric)
      _ = :gen_udp.send(state.socket, ~c"localhost", state.dest_port, iodata)
      {:noreply, state}
    end
  end
end
