#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule TCPEchoServer.IntegrationTest do
  use ExUnit.Case, async: true

  test "sends back the received data" do
    {:ok, socket} =
      :gen_tcp.connect(~c"localhost", 4000, [:binary, active: false])

    assert :ok = :gen_tcp.send(socket, "Hello world\n")

    assert {:ok, data} = :gen_tcp.recv(socket, 0, 500)
    assert data == "Hello world\n"
  end

  test "handles fragmented data" do
    {:ok, socket} =
      :gen_tcp.connect(~c"localhost", 4000, [:binary, active: false])

    assert :ok = :gen_tcp.send(socket, "Hello")
    assert :ok = :gen_tcp.send(socket, " world\nand one more\n")

    assert {:ok, data} = :gen_tcp.recv(socket, 0, 500)
    assert data == "Hello world\nand one more\n"
  end

  test "handles multiple clients simultaneously" do
    tasks =
      for _ <- 1..5 do
        Task.async(fn -> 
          {:ok, socket} =
            :gen_tcp.connect(~c"localhost", 4000, [:binary, active: false])

          assert :ok = :gen_tcp.send(socket, "Hello world\n")

          assert {:ok, data} = :gen_tcp.recv(socket, 0, 500)
          assert data == "Hello world\n"
        end)
      end

    Task.await_many(tasks) 
  end
end
