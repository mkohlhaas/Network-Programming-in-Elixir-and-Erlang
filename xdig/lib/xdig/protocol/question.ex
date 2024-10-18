#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule XDig.Protocol.Question do
  @moduledoc """
  A struct to represent a DNS question.
  """

  @type t() :: %__MODULE__{}

  defstruct [
    :qname,
    :qtype,
    :qclass
  ]
end
