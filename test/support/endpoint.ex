defmodule Exotus.Endpoint do
  use Plug.Router

  plug Plug.Logger
  plug :match
  plug :dispatch

  forward "/files", to: Exotus.Plug.Router, init_opts: [max_size: 1024]

  get "/" do
    Plug.Conn.send_file(conn, 200, "test/static/index.html")
  end

  get "/tus.min.js" do
    Plug.Conn.send_file(conn, 200, "test/static/tus.min.js")
  end

  match _ do
    send_resp(conn, 400, "")
  end
end
