defmodule RateLimitedServer do
  use Application

  def start(_type, _args) do
    # don't run if we're testing

    Supervisor.start_link(
      children(),
      strategy: :one_for_one,
      name: RateLimitedServer.Supervisor
    )
  end

  def children() do
    [
      {RateLimitedServer.Jobs, rate_limit()},
      {
        Plug.Cowboy,
        scheme: :http, plug: RateLimitedServer.Web, options: [port: 4000]
      }
    ]
  end

  def rate_limit() do
    case Mix.env() do
      :test -> 100
      _ -> 60 * 1000
    end
  end
end
