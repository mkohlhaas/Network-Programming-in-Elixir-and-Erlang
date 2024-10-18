#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule XDig.ProtocolTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest XDig.Protocol

  property "encoding and decoding sequences of strings" do
    check all(
            strings <- list_of(string(:alphanumeric, min_length: 1)),
            rest <- binary()
          ) do
      assert strings
             |> XDig.Protocol.encode_strings()
             |> IO.iodata_to_binary()
             |> Kernel.<>(rest)
             |> XDig.Protocol.decode_strings() == {strings, rest}
    end
  end
end
