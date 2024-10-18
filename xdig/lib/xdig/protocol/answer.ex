#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule XDig.Protocol.Answer do
  @moduledoc """
  A struct to represent a DNS answer.
  """

  defstruct [
    :name,
    :type,
    :class,
    :ttl,
    :rdata
  ]
end
