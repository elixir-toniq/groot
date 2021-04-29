defmodule Groot.MixProject do
  use Mix.Project

  @version "0.1.2"

  def project do
    [
      app: :groot,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      description: description(),
      package: package(),
      name: "Groot",
      source_url: "https://github.com/keathley/groot",
      docs: docs(),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Groot.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:hlclock, "~> 1.0"},

      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:local_cluster, "~> 1.0", only: [:dev, :test]},
      {:schism, "~> 1.0", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev},
    ]
  end

  def aliases do
    [
      test: ["test --no-start"]
    ]
  end

  def description do
    """
    Groot is a distributed KV store built on distributed erlang, LWW Register
    CRDTS, and Hybrid Logical Clocks.
    """
  end

  def package do
    [
      name: "groot",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/keathley/groot"},
    ]
  end

  def docs do
    [
      source_ref: "v#{@version}",
      source_url: "https://github.com/keathley/groot",
      main: "Groot",
    ]
  end
end
