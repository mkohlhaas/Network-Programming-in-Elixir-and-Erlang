#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule RedisClient.StateMachineTest do
  use ExUnit.Case, async: true

  alias RedisClient.StateMachine

  describe "command/2" do
    test "can send a PING command" do
      pool = start_link_supervised!({StateMachine, host: ~c"localhost", port: 6379})

      assert StateMachine.command(pool, ["PING"]) == {:ok, "PONG"}
    end

    test "returns an error if the client is not connected" do
      pool = start_link_supervised!({StateMachine, host: ~c"localhost", port: 9999})

      assert StateMachine.command(pool, ["PING"]) ==
               {:error, :disconnected}
    end

    test "supports multiple concurrent callers through queuing" do
      pool =
        start_link_supervised!(
          {StateMachine, host: ~c"localhost", port: 6379}
        )

      tasks =
        for _ <- 1..50 do
          Task.async(fn -> StateMachine.command(pool, ["PING"]) end)
        end

      results = Task.await_many(tasks)
      assert length(results) == 50
      assert Enum.all?(results, &(&1 == {:ok, "PONG"}))
    end

    test "doesn't leak messages" do
      Process.flag(:trap_exit, true)

      pool = start_link_supervised!({StateMachine, host: ~c"localhost", port: 6379})

      {:timeout, _} = catch_exit(StateMachine.command(pool, ["PING"], _timeout = 0))

      refute_receive _any, 100

      assert StateMachine.command(pool, ["PING"]) == {:ok, "PONG"}
    end

    test "returns errors to all waiting clients if the connection breaks" do
      pool = start_link_supervised!({StateMachine, host: ~c"localhost", port: 6379})

      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            StateMachine.command(pool, ["BLPOP", "my_list", "1000"])
          end)
        end

      {:connected, %{socket: socket}} = :sys.get_state(pool)
      send(pool, {:tcp_closed, socket})

      assert [_ | _] = results = Task.await_many(tasks)
      assert Enum.all?(results, &(&1 == {:error, :disconnected}))
    end
  end
end
