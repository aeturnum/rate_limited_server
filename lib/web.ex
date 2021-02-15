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
    # For some reason the with clause isn't working like I expect so I need to do this dumb try catch block?
    try do
      with conn <- Plug.Conn.fetch_query_params(conn),
           {:ok, queue_name} = Map.fetch(conn.query_params, "queue"),
           {:ok, message} = Map.fetch(conn.query_params, "message") do
        Jobs.add_job(queue_name, fn -> IO.puts(message) end)
        Plug.Conn.send_resp(conn, 200, "")
      end
    rescue
      MatchError ->
        IO.puts("Got match error in recieve-message")
        Plug.Conn.send_resp(conn, 400, "Incorrect Parameters")
    end
  end

  match _ do
    Plug.Conn.send_resp(conn, 404, "Not Found")
  end
end
