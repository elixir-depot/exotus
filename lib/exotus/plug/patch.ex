defmodule Exotus.Plug.Patch do
  @moduledoc false
  use Plug.Router

  def call(conn, path) do
    conn
    |> assign(:path, path)
    |> super(path)
  end

  plug :enforce_content_type
  plug :find_file
  plug :match
  plug :dispatch

  match _ do
    with {:ok, offset} <- fetch_offset(conn),
         {:ok, body, conn} <-
           Plug.Conn.read_body(conn, length: conn.private.exotus_config.max_size),
         {:ok, offset} <- Exotus.Upload.append(conn.assigns.file, offset, body) do
      conn
      |> put_resp_header("upload-offset", Integer.to_string(offset))
      |> send_resp(:no_content, "")
    else
      {:more, _partial_body, conn} -> send_resp(conn, :request_entity_too_large, "")
      {:error, :file_write_error} -> send_resp(conn, :internal_server_error, "")
      {:error, :file_size_exceeded} -> send_resp(conn, :request_entity_too_large, "")
      {:error, :offset_mismatch} -> send_resp(conn, :conflict, "")
    end
  end

  defp enforce_content_type(conn, _) do
    case get_req_header(conn, "content-type") do
      ["application/offset+octet-stream"] ->
        conn

      _ ->
        conn
        |> put_status(:unsupported_media_type)
        |> halt()
    end
  end

  defp find_file(conn, _) do
    case Exotus.Registry.get_upload(conn.assigns.path |> Path.join()) do
      {:ok, file} ->
        assign(conn, :file, file)

      _ ->
        conn
        |> send_resp(:not_found, "")
        |> halt()
    end
  end

  defp fetch_offset(conn) do
    with [offset_header] <- get_req_header(conn, "upload-offset"),
         {offset, ""} <- Integer.parse(offset_header) do
      {:ok, offset}
    else
      _ -> {:error, :offset_mismatch}
    end
  end
end
