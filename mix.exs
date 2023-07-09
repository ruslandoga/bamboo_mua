defmodule Bamboo.Mua.MixProject do
  use Mix.Project

  @version "0.1.0"
  @repo_url "https://github.com/ruslandoga/bamboo_mua"

  def project do
    [
      app: :bamboo_mua,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # hex
      package: package(),
      description: "Bamboo adapter for Mua, a minimal SMTP client",
      # docs
      name: "Bamboo.Mua",
      docs: [
        source_url: @repo_url,
        source_ref: "v#{@version}",
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"],
        skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bamboo, "~> 2.3"},
      {:mail, "~> 0.2.3"},
      {:mua, github: "ruslandoga/mua"},
      {:castore, "~> 0.1.0 or ~> 1.0", optional: true},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.29", only: :dev}
    ]
  end
end
