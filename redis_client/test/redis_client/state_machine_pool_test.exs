#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule RedisClient.StateMachinePoolTest do
  use ExUnit.Case, async: true

  alias RedisClient.StateMachinePool

  test "whole flow" do
    start_link_supervised!({StateMachinePool, name: TestPool, pool_size: 4, host: ~c"localhost", port: 6379})

    assert StateMachinePool.command(TestPool, ["PING"]) == {:ok, "PONG"}
  end
end
