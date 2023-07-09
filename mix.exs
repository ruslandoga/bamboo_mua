defmodule Bamboo.Mua.MixProject do
  use Mix.Project

  def project do
    [
      app: :bamboo_mua,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:bamboo, "~> 2.3"},
      {:mail, "~> 0.2.3"},
      {:castore, "~> 0.1.0 or ~> 1.0"},
      {:mua, github: "ruslandoga/mua"}
    ]
  end
end
