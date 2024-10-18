#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule Mix.Tasks.ChatClient do
  use Mix.Task

  import Chat.Protocol

  alias Chat.Message.{Broadcast, Register}

  def run([] = _args) do
    {:ok, socket} =
      :gen_tcp.connect(~c"localhost", 4000, [:binary, active: :once]) 

    user = Mix.shell().prompt("Enter your username:") |> String.trim() 

    :ok = :gen_tcp.send(socket, encode_message(%Register{username: user}))

    receive_loop(user, socket, spawn_prompt_task(user)) 
  end

  defp spawn_prompt_task(username) do
    Task.async(fn -> Mix.shell().prompt("#{username}# ") end)
  end

  defp receive_loop(username, socket, %Task{ref: ref} = prompt_task) do
    receive do
      # Task result, which is the contents of the message typed by the user.
      {^ref, message} -> 
        broadcast = %Broadcast{from_username: username, contents: message}
        :ok = :gen_tcp.send(socket, encode_message(broadcast))
        receive_loop(username, socket, spawn_prompt_task(username))

      {:DOWN, ^ref, _, _, _} -> 
        Mix.raise("Prompt task exited unexpectedly")

      {:tcp, ^socket, data} -> 
        :ok = :inet.setopts(socket, active: :once)
        handle_data(data)
        receive_loop(username, socket, prompt_task)

      {:tcp_closed, ^socket} -> 
        IO.puts("Server closed the connection")

      {:tcp_error, ^socket, reason} -> 
        Mix.raise("TCP error: #{inspect(reason)}")
    end
  end

  defp handle_data(data) do
    case decode_message(data) do
      {:ok, %Broadcast{} = message, ""} ->
        IO.puts("\n#{message.from_username}> #{message.contents}")

      _other ->
        Mix.raise(
          "Expected a complete broadcast message and nothing else, " <>
            "got: #{inspect(data)}"
        )
    end
  end
end
