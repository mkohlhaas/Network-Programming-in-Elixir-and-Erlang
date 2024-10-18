#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
{:ok, _} = Application.ensure_all_started(:inets)
{:ok, _} = Application.ensure_all_started(:crypto)

defmodule Frame do
  def question_strings(strings) do
    [Enum.map(strings, &[byte_size(&1), &1]) | [0x00]]
  end

  def decode_strings(<<0x00, rest::binary>>), do: {[], rest}

  def decode_strings(<<len::8, rest::binary>>) do
    <<str::binary-size(len), rest::binary>> = rest
    {strings, rest} = decode_strings(rest)
    {[str | strings], rest}
  end
end

server_address = {8, 8, 8, 8}
server_port = 53

{:ok, socket} = :gen_udp.open(0, [:binary, active: false])

message_id = :crypto.strong_rand_bytes(2)

question = [
  # Header
  <<
    message_id::binary-size(2),
    _qr = 0::1,
    _opcode = 0::4,
    _aa = 0::1,
    _tc = 0::1,
    _rd = 1::1,
    _ra = 0::1,
    _z = 0::3,
    _rcode = 0::4,
    _qdcount = 1::16,
    _ancount = 0::16,
    _nscount = 0::16,
    _arcount = 0::16
  >>,
  # Question
  question_meat = [
    Frame.question_strings(["github", "com"]),
    <<_qtype = 0x0001::16>>,
    <<_qclass = 0x0001::16>>
  ]
]

:ok = :gen_udp.send(socket, server_address, server_port, question)

{:ok, {^server_address, ^server_port, response}} = :gen_udp.recv(socket, 0, 5000)

dbg(response)

<<
  # Header
  ^message_id::binary-size(2),
  # QR
  1::1,
  # OPCODE
  0::4,
  _aa::1,
  _tc::1,
  _rd::1,
  _ra::1,
  # Z
  0::3,
  rcode::4,
  1::16,
  # ANCount
  1::16,
  # NSCount
  0::16,
  # ARCount
  0::16,
  answer::binary
>> = response

unless rcode == 0 do
  raise "RCODE was not 0: #{inspect(rcode)}"
end

question_meat = IO.iodata_to_binary(question_meat)

<<^question_meat::binary, rest::binary>> = answer

{labels, rest} =
  case rest do
    <<0b11::2, offset::14, rest::binary>> ->
      offset_msg = :binary.part(response, offset, byte_size(response) - offset)
      {labels, _rest} = Frame.decode_strings(offset_msg)
      {labels, rest}

    other ->
      Frame.decode_strings(other)
  end

dbg(labels)

<<
  type::16,
  # CLASS
  1::16,
  ttl::32,
  rdlength::16,
  rest::binary
>> = rest

dbg(ttl)

<<rdata::binary-size(rdlength)>> = rest

case type do
  _a = 0x0001 ->
    <<ip1::8, ip2::8, ip3::8, ip4::8>> = rdata
    IO.puts("A record: #{ip1}.#{ip2}.#{ip3}.#{ip4}")
end
