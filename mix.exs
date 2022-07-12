defmodule Dune.MixProject do
  use Mix.Project

  @version "0.2.4"
  @github_url "https://github.com/functional-rewire/dune"

  def project do
    [
      app: :dune,
      version: @version,
      elixir: "~> 1.13.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: preferred_cli_env(),

      # Hex
      description: "A sandbox for Elixir to safely evaluate untrusted code from user input",
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp preferred_cli_env do
    [
      docs: :docs,
      "hex.publish": :docs,
      dialyzer: :test
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # CI
      {:dialyxir, "~> 1.0", only: :test, runtime: false},
      # DOCS
      {:ex_doc, "~> 0.24", only: :docs, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["functional-rewire", "sabiwara"],
      licenses: ["MIT"],
      links: %{"GitHub" => @github_url},
      files: ~w(lib mix.exs .formatter.exs README.md LICENSE.md CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "Dune",
      source_ref: "v#{@version}",
      source_url: @github_url,
      homepage_url: @github_url,
      extras: ["README.md", "CHANGELOG.md", "LICENSE.md"]
    ]
  end
end
