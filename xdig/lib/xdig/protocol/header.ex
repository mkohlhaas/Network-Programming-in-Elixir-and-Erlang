#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule XDig.Protocol.Header do
  @moduledoc """
  A struct to represent a DNS header.
  """

  @type t() :: %__MODULE__{}

  defstruct [
    :message_id,
    :qr,
    :opcode,
    :rcode,
    qd_count: 0,
    an_count: 0,
    ns_count: 0,
    ar_count: 0,
    aa: 0,
    tc: 0,
    rd: 0,
    ra: 0
  ]
end
