defmodule Exotus.MixProject do
  use Mix.Project

  def project do
    [
      app: :exotus,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Exotus.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.10"},
      {:gen_state_machine, "~> 2.1"},
      {:plug_cowboy, "~> 2.0", only: :test},
      {:wallaby, "~> 0.26.0", runtime: false, only: :test}
    ]
  end
end
