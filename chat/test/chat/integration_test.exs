#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule ChatTest do
  use ExUnit.Case, async: true

  import Chat.Protocol

  alias Chat.Message.{Broadcast, Register}

  test "server closes connection if client sends register message twice" do
    {:ok, client} = :gen_tcp.connect(~c"localhost", 4000, [:binary]) # (1)
    encoded_message = encode_message(%Register{username: "jd"}) # (2)
    :ok = :gen_tcp.send(client, encoded_message) # (3)

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        :ok = :gen_tcp.send(client, encoded_message) # (4)
        assert_receive {:tcp_closed, ^client}, 500 # (5)
      end)

    assert log =~ "Invalid Register message" # (6)
  end

  test "broadcasting messages" do
    client_jd = connect_user("jd")
    client_amy = connect_user("amy")
    client_bern = connect_user("bern")

    # TODO: remove once we'll have "welcome" messages.
    Process.sleep(100)

    # Simulate Amy sending a message.
    broadcast_message = %Broadcast{from_username: "", contents: "hi"}
    encoded_message = encode_message(broadcast_message)
    :ok = :gen_tcp.send(client_amy, encoded_message)

    # Assert that Amy doesn't receive the message.
    refute_receive {:tcp, ^client_amy, _data}

    # Assert that the other clients receive the message.
    assert_receive {:tcp, ^client_jd, data}, 500
    assert {:ok, msg, ""} = decode_message(data)
    assert msg == %Broadcast{from_username: "amy", contents: "hi"}

    assert_receive {:tcp, ^client_bern, data}, 500
    assert {:ok, msg, ""} = decode_message(data)
    assert msg == %Broadcast{from_username: "amy", contents: "hi"}
  end

  defp connect_user(username) do 
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4000, [:binary])
    register_message = %Register{username: username}
    encoded_message = encode_message(register_message)
    :ok = :gen_tcp.send(socket, encoded_message)
    socket
  end
end
