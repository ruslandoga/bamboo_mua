defmodule Bamboo.Mua.MixProject do
  use Mix.Project

  @version "0.2.1"
  @repo_url "https://github.com/ruslandoga/bamboo_mua"

  def project do
    [
      app: :bamboo_mua,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # hex
      package: [
        licenses: ["MIT"],
        links: %{"GitHub" => @repo_url}
      ],
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
    [extra_applications: extra_applications(Mix.env())]
  end

  defp extra_applications(env) when env in [:dev, :test], do: [:inets]
  defp extra_applications(_env), do: []

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bamboo, "~> 2.0"},
      {:mail, "~> 0.3.0"},
      {:mua, "~> 0.2.3"},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.29", only: :dev},
      {:jason, "~> 1.4", only: :test}
    ]
  end
end
