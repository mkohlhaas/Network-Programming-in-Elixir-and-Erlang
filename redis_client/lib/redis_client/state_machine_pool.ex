#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule RedisClient.StateMachinePool do
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(options) do
    %{
      id: Keyword.fetch!(options, :name),
      start: {__MODULE__, :start_link, [options]}
    }
  end

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(options) do
    name = Keyword.fetch!(options, :name) 
    registry_name = registry_name(name)

    client_specs =
      for index <- 1..Keyword.fetch!(options, :pool_size) do
        child_options = Keyword.put(options, :registry_name, registry_name) 

        %{
          id: {:redis, index},
          start: {RedisClient.StateMachine, :start_link, [child_options]}
        }
      end

    children = [
      {Registry, keys: :duplicate, name: registry_name}, 
      %{
        id: :clients_supervisor,
        start: {
          Supervisor,
          :start_link,
          [client_specs, [strategy: :one_for_one]]
        }
      }
    ]

    Supervisor.start_link(children, strategy: :rest_for_one, name: name) 
  end

  @spec command(atom(), [String.t()]) :: {:ok, term()} | {:error, term()}
  def command(pool_name, command) do
    case Registry.lookup(registry_name(pool_name), :client) do
      [] ->
        {:error, :no_connections_available} 

      pids ->
        {pid, _value} = Enum.random(pids) 
        RedisClient.StateMachine.command(pid, command)
    end
  end

  defp registry_name(pool_name) do
    Module.concat(pool_name, Registry)
  end
end
