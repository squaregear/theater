defmodule Theater.Mixfile do
  use Mix.Project

  def project do
    [
      app: :theater,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "Theater",
      source_url: "https://github.com/squaregear/theater",
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Theater.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end

  defp description() do
    "A simple, scalable actor-model framework for Elixir"
  end

  defp package() do
    [
      name: "theater",
      licenses: ["MIT"],
      maintainers: ["Matthew Welch"],
      links: %{"GitHub" => "https://github.com/squaregear/theater"},
    ]
  end

end
