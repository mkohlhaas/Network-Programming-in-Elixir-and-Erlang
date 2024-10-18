#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule XDig.ServerTest do
  use ExUnit.Case

  # Integration test that uses `dig` just so that we don't risk bugs in the
  # client side making us believe that the server side is correct.
  @tag :capture_log
  test "adding records and using dig" do
    start_supervised!({XDig.Server, port: 9494})

    assert {_output, 0} =
             System.cmd("dig", ~w(elixir-lang.org @localhost -p 9494))

    XDig.Server.store(["elixir-lang", "org"], :a, <<4, 5, 6, 7>>)
    XDig.Server.store(["elixir-lang", "org"], :a, <<4, 5, 6, 8>>)

    assert {output, 0} =
             System.cmd("dig", ~w(elixir-lang.org @localhost -p 9494))

    assert output =~ "elixir-lang.org.\t300\tIN\tA\t4.5.6.7"
    assert output =~ "elixir-lang.org.\t300\tIN\tA\t4.5.6.8"
  end
end
