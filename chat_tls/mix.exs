#---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
#---
defmodule Chat.MixProject do
  use Mix.Project

  def project do
    [
      app: :chat,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: [test: ["compile.app --force", "test"]]
    ]
  end

  defp deps do
    [{:thousand_island, "~> 0.6.4"}]
  end

  def application do
    [
      extra_applications: [:logger, :ssl],
      mod: application_mod()
    ]
  end

  defp application_mod do
    cond do
      System.get_env("POOL") ->
        {Chat.AcceptorPool.Application, []}

      System.get_env("THOUSAND_ISLAND") ->
        {Chat.ThousandIsland.Application, []}

      true ->
        {Chat.Application, []}
    end
  end
end
