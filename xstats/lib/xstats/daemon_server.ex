#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule XStats.DaemonServer do
  @moduledoc """
  A process for receiving metrics from clients and flushing them to an
  I/O device.
  """

  use GenServer

  require Logger

  @flush_interval_millisec :timer.seconds(15)


  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  # Only used in tests, not part of the public API.
  @doc false
  @spec fetch_value(GenServer.server(), String.t()) ::
          {:ok, number()} | :error
  def fetch_value(server, name) do
    GenServer.call(server, {:fetch_value, name})
  end

  ## State

  defstruct socket: nil, metrics: %{}, flush_io_device: nil

  ## Callbacks

  @impl true
  def init(options) do
    port = Keyword.fetch!(options, :port)
    flush_io_device = Keyword.get(options, :flush_io_device, :stdio) 

    case :gen_udp.open(port, [:binary, active: true]) do
      {:ok, socket} ->
        :timer.send_interval(@flush_interval_millisec, self(), :flush) 
        {:ok, %__MODULE__{socket: socket, flush_io_device: flush_io_device}}

      {:error, reason} ->
        {:stop, reason}
    end
  end


  @impl true
  def handle_call({:fetch_value, name}, _from, state) do
    case Map.fetch(state.metrics, name) do
      {:ok, {_type, value}} -> {:reply, {:ok, value}, state}
      :error -> {:reply, :error, state}
    end
  end

  @impl true
  def handle_info(message, state)

  def handle_info(
        {:udp, socket, _ip, _port, data},
        %__MODULE__{socket: socket} = state
      ) do
    {metrics, _errors} = XStats.Protocol.parse_metrics(data) 
    state = Enum.reduce(metrics, state, &process_metric/2)
    {:noreply, state}
  end

  def handle_info(:flush, %__MODULE__{} = state) do
    IO.puts(state.flush_io_device, """
    ===============
    Current metrics
    ===============
    """)
    
    state =
      update_in(state.metrics, fn metrics ->
        Map.new(metrics, fn
          {name, {:counter, value}} ->
            IO.puts(state.flush_io_device, "#{name}:\t#{value}")
            {name, {:counter, 0}} 
            
          {name, {:gauge, value}} ->
            IO.puts(state.flush_io_device, "#{name}:\t#{value}")
            {name, {:gauge, value}} 
          end)
        end)
    
    IO.puts(state.flush_io_device, "\n\n\n")

    {:noreply, state}
  end

  ## Helpers

  defp process_metric({:gauge, name, value}, %__MODULE__{} = state) do
    put_in(state.metrics[name], {:gauge, value}) 
  end

  defp process_metric({:counter, name, value}, %__MODULE__{} = state) do
    case state.metrics[name] || {:counter, 0} do
      {:counter, current} ->
        put_in(state.metrics[name], {:counter, current + value})

      _other -> 
        state
    end
  end
end
