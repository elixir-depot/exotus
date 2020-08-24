defmodule Exotus.Plug.Post do
  use Plug.Router

  plug :fetch_length
  plug :match
  plug :dispatch

  match _ do
    Exotus.Upload.start_link(%{
      id: "abc",
      content_length: conn.assigns.length,
      metadata: metadata(conn)
    })

    conn
    |> put_resp_header("location", "abc")
    |> send_resp(:created, "")
  end

  defp metadata(conn) do
    case get_req_header(conn, "upload-metadata") do
      [meta] -> meta
      _ -> ""
    end
  end

  defp fetch_length(conn, _) do
    with :known <- type_of_length(conn) do
      [length] = get_req_header(conn, "upload-length")
      {integer, ""} = Integer.parse(length)
      assign(conn, :length, integer)
    else
      :deferred ->
        assign(conn, :length, :deferred)

      :error ->
        conn
        |> put_status(:bad_request)
        |> halt()
    end
  end

  defp type_of_length(conn) do
    case get_req_header(conn, "upload-defer-length") do
      ["1"] -> :deferred
      [] -> :known
      _ -> :error
    end
  end
end
