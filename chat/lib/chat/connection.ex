#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule Chat.Connection do
  use GenServer, restart: :temporary 

  alias Chat.Message.{Broadcast, Register}
  alias Chat.{BroadcastRegistry, UsernameRegistry}

  require Logger

  @spec start_link(:gen_tcp.socket()) :: GenServer.on_start()
  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  defstruct [:socket, :username, buffer: <<>>]

  @impl true
  def init(socket) do
    {:ok, %__MODULE__{socket: socket}}
  end

  @impl true
  def handle_info(message, state)

  def handle_info(
        {:tcp, socket, data},
        %__MODULE__{socket: socket} = state
      ) do
    state = update_in(state.buffer, &(&1 <> data))
    :ok = :inet.setopts(socket, active: :once)
    handle_new_data(state)
  end

  def handle_info(
        {:tcp_closed, socket},
        %__MODULE__{socket: socket} = state
      ) do
    {:stop, :normal, state}
  end

  def handle_info(
        {:tcp_error, socket, reason},
        %__MODULE__{socket: socket} = state
      ) do
    Logger.error("TCP connection error: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  def handle_info({:broadcast, %Broadcast{} = message}, state) do
    encoded_message = Chat.Protocol.encode_message(message)
    :ok = :gen_tcp.send(state.socket, encoded_message)
    {:noreply, state}
  end


  ## Helpers

  defp handle_new_data(state) do
    case Chat.Protocol.decode_message(state.buffer) do
      {:ok, message, rest} ->
        state = put_in(state.buffer, rest)

        case handle_message(message, state) do 
          {:ok, state} -> handle_new_data(state)
          :error -> {:stop, :normal, state}
        end

      :incomplete ->
        {:noreply, state}

      :error ->
        Logger.error("Received invalid data, closing connection")
        {:stop, :normal, state}
    end
  end

  defp handle_message(
         %Register{username: username},
         %__MODULE__{username: nil} = state
       ) do
    {:ok, _} = Registry.register(BroadcastRegistry, :broadcast, :no_value)
    {:ok, _} = Registry.register(UsernameRegistry, username, :no_value) 
    {:ok, put_in(state.username, username)}
  end

  defp handle_message(%Register{}, _state) do
    Logger.error("Invalid Register message, had already received one")
    :error 
  end

  defp handle_message(%Broadcast{}, %__MODULE__{username: nil}) do 
    Logger.error("Invalid Broadcast message, had not received a Register")
    :error 
  end

  defp handle_message(%Broadcast{} = message, state) do 
    sender = self()
    message = %Broadcast{message | from_username: state.username} 

    Registry.dispatch(BroadcastRegistry, :broadcast, fn entries -> 
      Enum.each(entries, fn {pid, _value} ->
        if pid != sender do 
          send(pid, {:broadcast, message}) 
        end
      end)
    end)

    {:ok, state}
  end
end
