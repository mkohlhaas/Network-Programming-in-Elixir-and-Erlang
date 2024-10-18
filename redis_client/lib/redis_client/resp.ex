#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule RedisClient.RESP do
  @moduledoc """
  This module provides functions to work with the [Redis binary
  protocol](http://redis.io/topics/protocol).
  """

  defmodule ParseError do
    defexception [:message]
  end

  defmodule Error do
    defexception [:message]
  end

  @type redis_value :: binary | integer | nil | %Error{} | [redis_value]
  @type on_decode(value) :: {:ok, value, binary} | {:continuation, (binary -> on_decode(value))}

  @crlf "\r\n"
  @crlf_iodata [?\r, ?\n]

  @doc ~S"""
  Encodes a list of Elixir terms to a Redis (RESP) array.

  This function returns an iodata (instead of a binary) because the encoded
  result is usually sent to Redis through `:gen_tcp.send/2` or similar. It can
  be converted to a binary with `IO.iodata_to_binary/1`.

  All elements of `elems` are converted to strings with `to_string/1`, hence
  this function supports encoding everything that implements `String.Chars`.

  ## Examples

      iex> iodata = RedisClient.RESP.encode(["SET", "mykey", 1])
      iex> IO.iodata_to_binary(iodata)
      "*3\r\n$3\r\nSET\r\n$5\r\nmykey\r\n$1\r\n1\r\n"

  """
  @spec encode([String.Chars.t()]) :: iodata
  def encode(items) when is_list(items) do
    encode(items, [], 0)
  end

  defp encode([item | rest], acc, count) do
    item = to_string(item)
    new_acc = [acc, [?$, Integer.to_string(byte_size(item)), @crlf_iodata, item, @crlf_iodata]]
    encode(rest, new_acc, count + 1)
  end

  defp encode([], acc, count) do
    [?*, Integer.to_string(count), @crlf_iodata, acc]
  end

  @doc ~S"""
  Decodes a RESP-encoded value from the given `data`.

  Returns `{:ok, value, rest}` if a value is decoded successfully, or a
  continuation in the form `{:continuation, fun}` if the data is incomplete.

  ## Examples

      iex> RedisClient.RESP.decode("+OK\r\ncruft")
      {:ok, "OK", "cruft"}

      iex> RedisClient.RESP.decode("-ERR wrong type\r\n")
      {:ok, %RedisClient.RESP.Error{message: "ERR wrong type"}, ""}

      iex> {:continuation, fun} = RedisClient.RESP.decode("+OK")
      iex> fun.("\r\n")
      {:ok, "OK", ""}

      iex> RedisClient.RESP.decode(":42\r\n")
      {:ok, 42, ""}

      iex> RedisClient.RESP.decode("$3\r\n\0hi\r\n")
      {:ok, <<0, "hi">>, ""}

  """
  @spec decode(binary) :: on_decode(redis_value)
  def decode(data)

  def decode("+" <> rest), do: decode_simple_string(rest)
  def decode("-" <> rest), do: decode_error(rest)
  def decode(":" <> rest), do: decode_integer(rest)
  def decode("$" <> rest), do: decode_bulk_string(rest)
  def decode("*" <> rest), do: decode_array(rest)
  def decode(""), do: {:continuation, &decode/1}

  def decode(<<byte>> <> _),
    do: raise(ParseError, message: "invalid type specifier (#{inspect(<<byte>>)})")

  @doc ~S"""
  Decodes `n` RESP-encoded values from the given `data`.

  Each element is decoded as described in `decode/1`. If an element can't be fully
  decoded or there are less than `n` elements encoded in `data`, then a
  continuation in the form of `{:continuation, fun}` is returned. Otherwise,
  `{:ok, values, rest}` is returned. If there's an error in decoding, a
  `RedisClient.RESP.ParseError` exception is raised.

  ## Examples

      iex> RedisClient.RESP.decode_multi("+OK\r\n+COOL\r\n", 2)
      {:ok, ["OK", "COOL"], ""}

      iex> {:continuation, fun} = RedisClient.RESP.decode_multi("+OK\r\n", 2)
      iex> fun.("+OK\r\n")
      {:ok, ["OK", "OK"], ""}

  """
  @spec decode_multi(binary, non_neg_integer) :: on_decode([redis_value])
  def decode_multi(data, nelems)

  # We treat the case when we have just one element to decode differently as it's
  # a very common case since single commands are treated as pipelines with just
  # one command in them.
  def decode_multi(data, 1) do
    resolve_cont(decode(data), &{:ok, [&1], &2})
  end

  def decode_multi(data, n) do
    take_elems(data, n, [])
  end

  # Type parsers

  defp decode_simple_string(data) do
    until_crlf(data)
  end

  defp decode_error(data) do
    data
    |> until_crlf()
    |> resolve_cont(&{:ok, %Error{message: &1}, &2})
  end

  defp decode_integer(""), do: {:continuation, &decode_integer/1}

  defp decode_integer("-" <> rest),
    do: resolve_cont(decode_integer_without_sign(rest), &{:ok, -&1, &2})

  defp decode_integer(bin), do: decode_integer_without_sign(bin)

  defp decode_integer_without_sign("") do
    {:continuation, &decode_integer_without_sign/1}
  end

  defp decode_integer_without_sign(<<digit, _::binary>> = bin) when digit in ?0..?9 do
    resolve_cont(decode_integer_digits(bin, 0), fn i, rest ->
      resolve_cont(until_crlf(rest), fn
        "", rest ->
          {:ok, i, rest}

        <<char, _::binary>>, _rest ->
          raise ParseError, message: "expected CRLF, found: #{inspect(<<char>>)}"
      end)
    end)
  end

  defp decode_integer_without_sign(<<non_digit, _::binary>>) do
    raise ParseError, message: "expected integer, found: #{inspect(<<non_digit>>)}"
  end

  defp decode_integer_digits(<<digit, rest::binary>>, acc) when digit in ?0..?9,
    do: decode_integer_digits(rest, acc * 10 + (digit - ?0))

  defp decode_integer_digits(<<_non_digit, _::binary>> = rest, acc), do: {:ok, acc, rest}
  defp decode_integer_digits(<<>>, acc), do: {:continuation, &decode_integer_digits(&1, acc)}

  defp decode_bulk_string(rest) do
    resolve_cont(decode_integer(rest), fn
      -1, rest ->
        {:ok, nil, rest}

      size, rest ->
        decode_string_of_known_size(rest, size)
    end)
  end

  defp decode_string_of_known_size(data, size) do
    case data do
      <<str::bytes-size(size), @crlf, rest::binary>> ->
        {:ok, str, rest}

      _ ->
        {:continuation, &decode_string_of_known_size(data <> &1, size)}
    end
  end

  defp decode_array(rest) do
    resolve_cont(decode_integer(rest), fn
      -1, rest ->
        {:ok, nil, rest}

      size, rest ->
        take_elems(rest, size, [])
    end)
  end

  defp until_crlf(data, acc \\ "")

  defp until_crlf(<<@crlf, rest::binary>>, acc), do: {:ok, acc, rest}
  defp until_crlf(<<>>, acc), do: {:continuation, &until_crlf(&1, acc)}
  defp until_crlf(<<?\r>>, acc), do: {:continuation, &until_crlf(<<?\r, &1::binary>>, acc)}
  defp until_crlf(<<byte, rest::binary>>, acc), do: until_crlf(rest, <<acc::binary, byte>>)

  defp take_elems(data, 0, acc) do
    {:ok, Enum.reverse(acc), data}
  end

  defp take_elems(<<_, _::binary>> = data, n, acc) when n > 0 do
    resolve_cont(decode(data), fn elem, rest ->
      take_elems(rest, n - 1, [elem | acc])
    end)
  end

  defp take_elems(<<>>, n, acc) do
    {:continuation, &take_elems(&1, n, acc)}
  end

  defp resolve_cont({:ok, val, rest}, ok) when is_function(ok, 2), do: ok.(val, rest)

  defp resolve_cont({:continuation, cont}, ok),
    do: {:continuation, fn new_data -> resolve_cont(cont.(new_data), ok) end}
end
