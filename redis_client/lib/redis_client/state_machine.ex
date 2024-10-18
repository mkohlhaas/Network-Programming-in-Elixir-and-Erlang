#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule RedisClient.StateMachine do
  alias RedisClient.RESP

  require Logger

  @backoff_time 1_000

  @spec child_spec(keyword) :: Supervisor.child_spec()
  def child_spec(options) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [options]},
      type: :worker
    }
  end

  @spec start_link(keyword) :: :gen_statem.start_ret()
  def start_link(options) do
    :gen_statem.start_link(__MODULE__, options, _gen_statem_options = [])
  end

  @spec command(pid(), [String.t()], timeout()) :: {:ok, term()} | {:error, term()}
  def command(pid, command, timeout \\ 5000) do
    :gen_statem.call(pid, {:command, command}, timeout)
  end


  @behaviour :gen_statem

  # The "data" (that is, the equivalent of the "state" in a GenServer).
  defstruct [:host, :port, :socket, :continuation, queue: :queue.new()]
  

  @impl :gen_statem
  def callback_mode, do: [:state_functions, :state_enter]

  @impl :gen_statem
  def init(options) do
    if registry = options[:registry_name] do
      {:ok, _} = Registry.register(registry, :client, :no_value)
    end

    data = %__MODULE__{
      host: Keyword.fetch!(options, :host),
      port: Keyword.fetch!(options, :port)
    }

    actions = [{:next_event, :internal, :connect}]
    {:ok, :disconnected, data, actions}
  end

  ## Disconnected state

  def disconnected(:internal, :connect, data) do
    options = [:binary, active: :once]

    case :gen_tcp.connect(data.host, data.port, options, 5000) do
      {:ok, socket} ->
        data = %__MODULE__{data | socket: socket}
        {:next_state, :connected, data} 

      {:error, reason} ->
        Logger.error("Failed to connect: #{:inet.format_error(reason)}")
        timer_action = {{:timeout, :reconnect}, @backoff_time, nil} 
        {:keep_state_and_data, [timer_action]} 
    end
  end

  def disconnected(:enter, :disconnected, _data) do
    :keep_state_and_data
  end

  def disconnected(:enter, :connected, data) do
    actions =
      for caller <- :queue.to_list(data.queue) do
        {:reply, caller, {:error, :disconnected}}
      end

    data = %__MODULE__{data | queue: :queue.new(), socket: nil, continuation: nil}
    {:keep_state, data, actions}
  end

  def disconnected({:timeout, :reconnect}, nil, _data) do
    actions = [{:next_event, :internal, :connect}]
    {:keep_state_and_data, actions}
  end

  def disconnected({:call, from}, {:command, _command}, _data) do
    actions = [{:reply, from, {:error, :disconnected}}]
    {:keep_state_and_data, actions}
  end

  ## Connected state

  def connected(:enter, _old_state = :disconnected, _data) do
    actions = [{{:timeout, :reconnect}, :cancel}]
    {:keep_state_and_data, actions}
  end

  def connected({:call, from}, {:command, command}, data) do
    :ok = :gen_tcp.send(data.socket, RESP.encode(command))
    data = update_in(data.queue, &:queue.in(from, &1))
    {:keep_state, data}
  end

  def connected(:info, {:tcp, socket, bytes}, %__MODULE__{socket: socket} = data) do
    :ok = :inet.setopts(data.socket, active: :once)
    {data, actions} = handle_new_bytes(data, bytes)
    {:keep_state, data, actions}
  end

  def connected(:info, {:tcp_error, socket, reason}, %__MODULE__{socket: socket} = data) do
    Logger.error("Connection error: #{:inet.format_error(reason)}")
    {:next_state, :disconnected, data}
  end

  def connected(:info, {:tcp_closed, socket}, %__MODULE__{socket: socket} = data) do
    Logger.error("Connection closed")
    {:next_state, :disconnected, data}
  end

  ## Helpers

  defp handle_new_bytes(data, bytes) do
    handle_new_bytes(data, bytes, _actions_acc = [])
  end

  defp handle_new_bytes(%__MODULE__{} = data, bytes, actions) do
    continuation = data.continuation || &RESP.decode/1

    case continuation.(bytes) do
      {:ok, response, rest} ->
        data = %__MODULE__{data | continuation: nil}
        {{:value, caller}, data} = get_and_update_in(data.queue, &:queue.out/1)
        actions = [{:reply, caller, {:ok, response}} | actions]
        handle_new_bytes(data, rest, actions)

      {:continuation, continuation} ->
        {%__MODULE__{data | continuation: continuation}, actions}
    end
  end
end
