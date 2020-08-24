defmodule Exotus.MixProject do
  use Mix.Project

  def project do
    [
      app: :exotus,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description: description(),
      package: package(),
      name: "Exotus",
      source_url: "https://github.com/elixir-depot/exotus"
    ]
  end

  defp description() do
    "Elixir implementation of the tus protocol using plug."
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/elixir-depot/exotus"}
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
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:plug_cowboy, "~> 2.0", only: :test},
      {:wallaby, "~> 0.26.0", runtime: false, only: :test}
    ]
  end
end
