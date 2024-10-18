#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule XDig.Protocol do
  alias XDig.Protocol.{Answer, Header, Question}

  @class_internet_addresses 1

  @types [
    a: 1
  ]

  @doc ~S"""
  Decodes a DNS header.

      iex> header = <<207, 206, 129, 128, 0, 1, 0, 1, 0, 0, 0, 0>>
      iex> XDig.Protocol.decode_header(header)
      %XDig.Protocol.Header{
        message_id: <<207, 206>>,
        opcode: 0,
        aa: 0,
        an_count: 1,
        ar_count: 0,
        ns_count: 0,
        qd_count: 1,
        qr: 1,
        ra: 1,
        rcode: 0,
        rd: 1,
        tc: 0
      }

  """
  @spec decode_header(binary()) :: Header.t()
  def decode_header(header) when is_binary(header) do
    <<
      message_id::binary-size(2),
      qr::1,
      opcode::4,
      <<aa::1, tc::1, rd::1, ra::1>>,
      _z::3,
      rcode::4,
      qd_count::16,
      an_count::16,
      ns_count::16,
      ar_count::16
    >> = header

    %Header{
      message_id: message_id,
      qr: qr,
      opcode: opcode,
      rcode: rcode,
      qd_count: qd_count,
      an_count: an_count,
      ns_count: ns_count,
      ar_count: ar_count,
      aa: aa,
      tc: tc,
      rd: rd,
      ra: ra
    }
  end

  @doc """
  Encodes the given header.
  """
  @spec encode_header(Header.t()) :: binary()
  def encode_header(%Header{} = header) do
    <<
      header.message_id::binary,
      header.qr::1,
      header.opcode::4,
      <<header.aa::1, header.tc::1, header.rd::1, header.ra::1>>,
      _z = 0::3,
      header.rcode::4,
      header.qd_count::16,
      header.an_count::16,
      header.ns_count::16,
      header.ar_count::16
    >>
  end

  @doc """
  Decodes a DNS question and returns the question and whatever bytes are
  left.
  """
  @spec decode_question(binary()) :: {Question.t(), binary()}
  def decode_question(binary) do
    {qname, <<qtype::16, qclass::16, rest::binary>>} =
      decode_strings(binary)

    {%Question{qname: qname, qtype: decode_type(qtype), qclass: qclass},
     rest}
  end

  @doc """
  Encodes a DNS question to iodata.
  """
  @spec encode_question(Question.t()) :: iodata()
  def encode_question(%Question{} = question) do
    [
      encode_strings(question.qname),
      <<encode_type(question.qtype)::16>>,
      <<@class_internet_addresses::16>>
    ]
  end

  @doc """
  Decodes a DNS answer from a binary.

  `whole_response` is necessary due to DNS offset, the technique that the
  DNS protocol uses to avoid repeating the same domain name in the
  response.
  """
  @spec decode_answer(binary(), binary()) :: {Answer.t(), binary()}
  def decode_answer(whole_response, binary) do
    {labels, rest} =
      case binary do
        <<0b11::2, offset::14, rest::binary>> ->
          offset_msg =
            :binary.part(
              whole_response,
              offset,
              byte_size(whole_response) - offset
            )

          {labels, _rest} = decode_strings(offset_msg)
          {labels, rest}

        other ->
          decode_strings(other)
      end

    <<
      type::16,
      class::16,
      ttl::32,
      rdlength::16,
      rdata::size(rdlength)-binary,
      rest::binary
    >> = rest

    rdata =
      case {type, rdata} do
        {unquote(@types[:a]), <<a, b, c, d>>} -> {a, b, c, d}
      end

    answer = %Answer{
      name: labels,
      type: decode_type(type),
      class: class,
      ttl: ttl,
      rdata: rdata
    }

    {answer, rest}
  end

  @doc """
  Encodes a DNS answer to iodata.
  """
  @spec encode_answer(Answer.t()) :: iodata()
  def encode_answer(%Answer{} = answer) do
    [
      encode_strings(answer.name),
      <<encode_type(answer.type)::16>>,
      <<answer.class::16>>,
      <<answer.ttl::32>>,
      <<byte_size(answer.rdata)::16>>,
      answer.rdata
    ]
  end

  @doc """
  Encode a sequence of strings.

      iex> iodata = XDig.Protocol.encode_strings(["elixir-lang", "org"])
      iex> IO.iodata_to_binary(iodata)
      <<11, 101, 108, 105, 120, 105, 114, 45, 108,
        97, 110, 103, 3, 111, 114, 103, 0>>

  """
  @spec encode_strings([String.t()]) :: iodata()
  def encode_strings(strings) when is_list(strings) do
    [Enum.map(strings, &[byte_size(&1), &1]) | [0x00]]
  end


  @doc """
  Decodes a sequence of strings from a binary.
  """
  @spec decode_strings(binary()) :: {[String.t()], rest :: binary()}
  def decode_strings(binary)

  def decode_strings(<<0x00, rest::binary>>) do
    {[], rest}
  end

  def decode_strings(<<len::8, rest::binary>>) do
    <<str::binary-size(len), rest::binary>> = rest
    {strings, rest} = decode_strings(rest)
    {[str | strings], rest}
  end

  ## Helpers

  for {type, value} <- @types do
    defp encode_type(unquote(type)), do: unquote(value)
    defp decode_type(unquote(value)), do: unquote(type)
  end
end
