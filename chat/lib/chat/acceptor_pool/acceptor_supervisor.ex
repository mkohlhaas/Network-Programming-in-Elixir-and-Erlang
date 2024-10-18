#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule Chat.AcceptorPool.AcceptorSupervisor do
  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(options) do
    Supervisor.start_link(__MODULE__, options)
  end

  @impl true
  def init(options) do
    pool_size = Keyword.get(options, :pool_size, 10) 
    listen_socket = Keyword.fetch!(options, :listen_socket) 

    children =
      for index <- 1..pool_size do 
        spec = {Chat.AcceptorPool.Acceptor, listen_socket}
        Supervisor.child_spec(spec, id: "acceptor-#{index}") 
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
