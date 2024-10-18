#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule XStats.Protocol do
  @moduledoc """
  Functions for parsing and serializing metrics according to a
  text protocol inspired by [StatsD](https://github.com/statsd/statsd).
  """

  @type metric() ::
          {:gauge | :counter, name :: String.t(), value :: number()}

  @doc ~S"""
  Parses all the well-formed metrics in `packet`.

  metrics are separated by newline `\n` characters. They are all
  in the form:

      <name>:<value>|<type>

  where:

    * `name` is an arbitrary string
    * `value` is a number (float or integer)
    * `type` is one of `g` (gauge), or `c` (counter)

  Returns `{parsed, errors}` where `parsed` is a list of successfully-parsed
  metrics, and `errors` is a list of errors encountered while parsing.

  ## Examples

      iex> parse_metrics("reqs:1|c\nfoobar\nfloat:20.04|g\nset:0|g\n")
      {[
        {:counter, "reqs", 1},
        {:gauge, "float", 20.04},
        {:gauge, "set", 0}
      ], ["invalid line format: \"foobar\""]}

      iex> metric = {:gauge, "disk_used", 2020.83}
      iex> iodata = XStats.Protocol.encode_metric(metric)
      iex> data = IO.iodata_to_binary(iodata) <> "cruft"
      "disk_used:2020.83|g\ncruft"
      iex> XStats.Protocol.parse_metrics(data)
      {[{:gauge, "disk_used", 2020.83}], ["invalid line format: \"cruft\""]}


  """
  @spec parse_metrics(binary()) :: {[metric()], errors :: [binary()]}
  def parse_metrics(packet) when is_binary(packet) do
    lines = String.split(packet, "\n", trim: true)
    initial_acc = {_parsed = [], _errors = []}

    {parsed, errors} =
      Enum.reduce(lines, initial_acc, fn line, {parsed, errors} ->
        case parse_line(line) do
          {:ok, metric} -> {[metric | parsed], errors}
          {:error, error} -> {parsed, [error | errors]}
        end
      end)

    {Enum.reverse(parsed), Enum.reverse(errors)}
  end

  defp parse_line(line) do
    case String.split(line, ["|", ":"]) do
      [name, value, type] ->
        with {:ok, type} <- parse_type(type),
             {:ok, value} <- parse_number(value) do
          {:ok, {type, name, value}}
        end

      _other ->
        {:error, "invalid line format: #{inspect(line)}"}
    end
  end

  defp parse_type("c"), do: {:ok, :counter}
  defp parse_type("g"), do: {:ok, :gauge}
  defp parse_type(other), do: {:error, "invalid type: #{inspect(other)}"}

  defp parse_number(value) do
    case Integer.parse(value) do
      {int, ""} ->
        {:ok, int}

      _other ->
        case Float.parse(value) do
          {float, ""} -> {:ok, float}
          _other -> {:error, "invalid number: #{inspect(value)}"}
        end
    end
  end

  @doc ~S"""
  Encodes the given metric to iodata.

  ## Examples

      iex> IO.iodata_to_binary(encode_metric({:counter, "reqs", 10}))
      "reqs:10|c\n"
      iex> IO.iodata_to_binary(encode_metric({:gauge, "mem_used_mb", 8.23}))
      "mem_used_mb:8.23|g\n"

  """
  @spec encode_metric(metric()) :: iodata()
  def encode_metric({type, name, value})
      when is_binary(name) and is_number(value) do
    case type do
      :counter -> [name, ?:, to_string(value), "|c\n"]
      :gauge -> [name, ?:, to_string(value), "|g\n"]
    end
  end
end
