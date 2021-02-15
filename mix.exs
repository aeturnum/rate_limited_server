defmodule RateLimitedServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :rate_limited_server,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {RateLimitedServer, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # json!
      {:poison, "~> 4.0"},
      # webserver
      {:plug_cowboy, "~> 2.4.0"}
    ]
  end
end
