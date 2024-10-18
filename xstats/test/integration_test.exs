#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule IntegrationTest do
  use ExUnit.Case, async: true

  alias XStats.DaemonServer
  alias XStats.Reporter

  @port 9324

  setup do
    {:ok, string_io} = StringIO.open("")

    assert {:ok, daemon} =
             start_supervised(
               {DaemonServer, port: @port, flush_io_device: string_io}
             )

    assert {:ok, rep} = start_supervised({Reporter, dest_port: @port})
    %{daemon: daemon, reporter: rep, string_io: string_io}
  end

  test "reporting a counter metric", %{
    daemon: daemon,
    reporter: rep,
    string_io: string_io
  } do
    assert :ok = Reporter.increment_counter(rep, "reqs", 1)
    assert :ok = Reporter.increment_counter(rep, "reqs", 4)

    until_assert_passes(fn ->
      assert DaemonServer.fetch_value(daemon, "reqs") == {:ok, 5}
    end)

    send_and_flush_state(daemon, :flush)
    assert StringIO.flush(string_io) =~ "reqs:\t5\n"

    # Counter is reset.
    assert DaemonServer.fetch_value(daemon, "reqs") == {:ok, 0}
  end

  test "reporting a gauge metric", %{
    daemon: daemon,
    reporter: rep,
    string_io: string_io
  } do
    assert :ok = Reporter.set_gauge(rep, "dur", 103)

    until_assert_passes(fn ->
      assert DaemonServer.fetch_value(daemon, "dur") == {:ok, 103}
    end)

    assert :ok = Reporter.set_gauge(rep, "dur", 949)

    until_assert_passes(fn ->
      assert DaemonServer.fetch_value(daemon, "dur") == {:ok, 949}
    end)

    send_and_flush_state(daemon, :flush)
    assert StringIO.flush(string_io) =~ "dur:\t949\n"

    # Gauge is not reset.
    assert DaemonServer.fetch_value(daemon, "dur") == {:ok, 949}
  end

  test "reporting multiple (good and bad) metrics in one packet", %{
    daemon: daemon
  } do
    {:ok, socket} = :gen_udp.open(0, [:binary])

    packet = [
      XStats.Protocol.encode_metric({:gauge, "mem_used_mb", 49.2}),
      XStats.Protocol.encode_metric({:counter, "hits", 1}),
      XStats.Protocol.encode_metric({:counter, "hits", 2}),
      "invalid line\n",
      XStats.Protocol.encode_metric({:gauge, "mem_used_mb", 37.0})
    ]

    assert :ok = :gen_udp.send(socket, ~c"localhost", @port, packet)

    until_assert_passes(fn ->
      assert DaemonServer.fetch_value(daemon, "mem_used_mb") == {:ok, 37.0}
      assert DaemonServer.fetch_value(daemon, "hits") == {:ok, 3}
    end)
  end

  defp until_assert_passes(max_timeout \\ 500, fun)

  defp until_assert_passes(timeout, fun) when timeout < 0 do
    fun.()
  end

  defp until_assert_passes(timeout, fun) do
    fun.()
  rescue
    ExUnit.AssertionError ->
      Process.sleep(10)
      until_assert_passes(timeout - 10, fun)
  end

  defp send_and_flush_state(pid, message) do
    send(pid, message)
    :sys.get_state(pid)
    :ok
  end
end
