defmodule Anchor.MixProject do
  use Mix.Project

  def project do
    [
      app: :anchor,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_options: [warnings_as_errors: true],
      deps: deps(),
      description: "Architectural constraint checks for Elixir projects via Credo",
      package: package(),
      source_url: "https://github.com/cjpoll/anchor"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7"},
      {:yaml_elixir, "~> 2.9"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:hammox, "~> 0.7", only: :test}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/cjpoll/anchor"},
      maintainers: ["CJ Poll"]
    ]
  end
end
