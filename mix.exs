defmodule AshRateLimiter.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      aliases: aliases(),
      app: :ash_rate_limiter,
      consolidate_protocols: Mix.env() != :dev,
      deps: deps(),
      description: @moduledoc,
      dialyzer: [plt_add_apps: [:mix]],
      docs: docs(),
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      start_permanent: Mix.env() == :prod,
      version: @version
    ]
  end

  defp package do
    [
      maintainers: [
        "James Harton <james@harton.dev>"
      ],
      licenses: ["MIT"],
      links: %{
        "Source" => "https://github.com/ash-project/ash_rate_limiter",
        "Ash" => "https://www.ash-hq.org/"
      },
      source_url: "https://github.com/ash-project/ash_rate_limiter",
      files: ~w[lib src .formatter.exs mix.exs README* LICENSE* CHANGELOG* documentation]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE.md",
        "documentation/dsls/DSL-AshRateLimiter.md"
      ],
      filter_modules: ~r/^Elixir\.AshRateLimiter/
    ]
  end

  defp aliases do
    [
      "spark.formatter": "spark.formatter --extensions AshRateLimiter",
      "spark.cheat_sheets": "spark.cheat_sheets --extensions AshRateLimiter",
      docs: ["spark.cheat_sheets", "docs"],
      credo: "credo --strict"
    ]
  end

  defp elixirc_paths(env) when env in [:dev, :test], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.0"},
      {:hammer, "~> 7.0"},
      {:spark, "~> 2.0"},
      {:simple_sat, "~> 0.1", only: [:dev, :test]},
      {:splode, "~> 0.2"},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.37", only: [:dev, :test], runtime: false},
      {:faker, "~> 0.18", only: [:dev, :test]},
      {:git_ops, "~> 2.0", only: [:dev, :test], runtime: false},
      {:igniter, "~> 0.5", only: [:dev, :test], optional: true},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:sourceror, "~> 1.7", only: [:dev, :test], optional: true}
    ]
  end
end
