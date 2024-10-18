#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule XStats.ProtocolTest do
  use ExUnit.Case, async: true

  import XStats.Protocol

  doctest XStats.Protocol, import: true

  describe "parse_metrics/1" do
    test "can parse :gauge metric" do
      assert {metrics, errors} =
               parse_metrics("""
               set:20|g
               foobar
               float:20.04|g
               set:0|g\
               """)

      assert metrics == [
               {:gauge, "set", 20},
               {:gauge, "float", 20.04},
               {:gauge, "set", 0}
             ]

      assert errors == ["invalid line format: \"foobar\""]
    end

    test "can parse :counter metric" do
      assert {[{:counter, "reqs", 3}], _errors} =
               parse_metrics("""
               reqs:3|c
               foo
               bar
               """)
    end

    test "returns an error if the type of the metric is invalid" do
      assert {[], _errors} = parse_metrics("duration:3|s\nfoo\nbar")
    end
  end

  describe "encode_metric/1" do
    test "with :counter" do
      assert encode({:counter, "reqs", 10}) == "reqs:10|c\n"
      assert encode({:counter, "reqs", 0}) == "reqs:0|c\n"
      assert encode({:counter, "reqs", 10.3}) == "reqs:10.3|c\n"
    end

    test "with :gauge" do
      assert encode({:gauge, "val", 1004}) == "val:1004|g\n"
      assert encode({:gauge, "val", 0}) == "val:0|g\n"
      assert encode({:gauge, "val", 10.3}) == "val:10.3|g\n"
    end
  end

  defp encode(metric) do
    metric |> encode_metric() |> IO.iodata_to_binary()
  end
end
