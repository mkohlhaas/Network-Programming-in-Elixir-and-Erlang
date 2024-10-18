#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule RedisClient.SocketPoolTest do
  use ExUnit.Case, async: true

  alias RedisClient.SocketPool

  describe "command/2" do
    test "can send a PING command" do
      pool = start_link_supervised!({SocketPool, host: ~c"localhost", port: 6379})

      assert SocketPool.command(pool, ["PING"]) == {:ok, "PONG"}
    end

    @tag :skip
    test "returns an error if the client is not connected" do
      pool = start_link_supervised!({SocketPool, host: ~c"localhost", port: 9999})

      assert SocketPool.command(pool, ["PING"]) ==
               {:error, :not_connected}
    end

    test "supports multiple concurrent callers through queuing" do
      pool =
        start_link_supervised!(
          {SocketPool, host: ~c"localhost", port: 6379}
        )

      tasks =
        for _ <- 1..50 do
          Task.async(fn -> SocketPool.command(pool, ["PING"]) end)
        end

      results = Task.await_many(tasks)
      assert length(results) == 50
      assert Enum.all?(results, &(&1 == {:ok, "PONG"}))
    end

    test "checks the socket back in if the caller crashes before handing it back" do
      pool =
        start_link_supervised!(
          {SocketPool, host: ~c"localhost", port: 6379}
        )

      {:ok, pid} =
        Task.start(fn ->
          # This command blocks for a while.
          SocketPool.command(pool, ["BLPOP", "my_list", "1000"])
        end)

      Process.sleep(50)

      Process.exit(pid, :kill)

      assert SocketPool.command(pool, ["PING"]) == {:ok, "PONG"}
    end
  end
end
