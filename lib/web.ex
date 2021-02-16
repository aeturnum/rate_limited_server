defmodule RateLimitedServer.Web do
  use Plug.Router

  alias RateLimitedServer.Jobs

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    Plug.Conn.send_resp(conn, 200, Poison.encode!(Jobs.status()))
  end

  get "/receive-message" do
    with conn <- Plug.Conn.fetch_query_params(conn),
         {:ok, queue_name} <- Map.fetch(conn.query_params, "queue"),
         {:ok, message} <- Map.fetch(conn.query_params, "message") do
      Jobs.add_job(queue_name, fn -> IO.puts(message) end)
      Plug.Conn.send_resp(conn, 200, "")
    else
      :error -> Plug.Conn.send_resp(conn, 400, "Incorrect Parameters")
    end
  end

  match _ do
    Plug.Conn.send_resp(conn, 404, "Not Found")
  end
end
