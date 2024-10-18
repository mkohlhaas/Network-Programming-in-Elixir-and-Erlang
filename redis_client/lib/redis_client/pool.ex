#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule RedisClient.Pool do
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(args) do
    {name, worker_args} = Keyword.pop!(args, :name)

    pool_args = [
      name: {:local, name},
      worker_module: RedisClientQueued,
      size: 5
    ]

    :poolboy.child_spec(name, pool_args, worker_args)
  end

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(worker_args) do
    pool_args = [worker_module: RedisClientQueued, size: 5]
    :poolboy.start_link(pool_args, worker_args)
  end

  @spec command(:poolboy.pool(), [String.t()]) ::
          {:ok, String.t()} | {:error, any()}
  def command(pool, command) do
    :poolboy.transaction(pool, fn client ->
      RedisClientQueued.command(client, command)
    end)
  end
end
