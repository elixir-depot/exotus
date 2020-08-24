defmodule Exotus.Plug.Post do
  @moduledoc false
  use Plug.Router

  plug :fetch_length
  plug :match
  plug :dispatch

  match _ do
    {:ok, file} =
      Exotus.Upload.start_link(%{
        id: "abc",
        content_length: conn.assigns.length,
        metadata: metadata(conn)
      })

    with %{halted: false} = conn <- maybe_do_upload(conn, file) do
      conn
      |> put_resp_header("location", "abc")
      |> send_resp(:created, "")
    end
  end

  defp metadata(conn) do
    case get_req_header(conn, "upload-metadata") do
      [meta] -> meta
      _ -> ""
    end
  end

  defp maybe_do_upload(conn, file) do
    case get_req_header(conn, "content-type") do
      ["application/offset+octet-stream"] ->
        with {:ok, body, conn} <-
               Plug.Conn.read_body(conn, length: conn.private.exotus_config.max_size),
             {:ok, offset} <- Exotus.Upload.append(file, 0, body) do
          conn
          |> put_resp_header("upload-offset", Integer.to_string(offset))
        else
          {:more, _partial_body, conn} ->
            send_resp(conn, :request_entity_too_large, "") |> halt()

          {:error, :file_write_error} ->
            send_resp(conn, :internal_server_error, "") |> halt()

          {:error, :file_size_exceeded} ->
            send_resp(conn, :request_entity_too_large, "") |> halt()

          {:error, :offset_mismatch} ->
            send_resp(conn, :conflict, "") |> halt()
        end

      _ ->
        conn
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
