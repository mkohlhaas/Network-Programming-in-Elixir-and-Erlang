#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule XDigTest do
  use ExUnit.Case, async: true

  doctest XDig

  describe "lookup/3" do
    test "works" do
      answers = XDig.lookup({1, 1, 1, 1}, :a, ["elixir-lang", "org"])

      assert [_ | _] = answers,
             "answers are not a non-empty list: #{inspect(answers)}"

      Enum.each(answers, fn answer ->
        assert %XDig.Protocol.Answer{
                 name: ["elixir-lang", "org"],
                 type: :a,
                 class: 1,
                 ttl: ttl,
                 rdata: {_, _, _, _}
               } = answer

        assert is_integer(ttl) and ttl >= 0,
               "ttl is not a non-negative integer: #{inspect(ttl)}"
      end)
    end
  end
end
