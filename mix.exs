defmodule Anchor.MixProject do
  use Mix.Project

  def project do
    [
      app: :anchor,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_options: [warnings_as_errors: true],
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description: "Architectural constraint checks for Elixir projects via Credo",
      package: package(),
      source_url: "https://github.com/cjpoll/anchor"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  # test/support holds shared test helpers (DND-5438: in-test compiled beam
  # fixtures), compiled only in the test env.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7"},
      {:yaml_elixir, "~> 2.9"},
      {:sourceror, "~> 1.7"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:hammox, "~> 0.7", only: :test},
      # DND-5480: Anchor.Backstop attaches to an Ecto repo's query event in a
      # consumer's test VM. Every Ecto project already has it; Anchor reads
      # telemetry maps and needs no Ecto in lib.
      {:telemetry, "~> 1.0", optional: true},
      # DND-5459: real Ecto macro shapes (use Ecto.Schema, from/2, Ecto.Multi) for
      # the aggregate write-source fixtures; never a runtime dependency.
      {:ecto, "~> 3.12", only: :test}
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
