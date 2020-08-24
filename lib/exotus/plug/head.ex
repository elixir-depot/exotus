defmodule Exotus.Plug.Head do
  use Plug.Router

  def call(conn, path) do
    conn
    |> assign(:path, path)
    |> super(path)
  end

  plug :disable_caching
  plug :find_file
  plug :match
  plug :dispatch

  match _ do
    case Exotus.Upload.status(conn.assigns.file) do
      %{length: length, offset: offset} when is_integer(length) and is_integer(offset) ->
        conn
        |> put_resp_header("upload-length", Integer.to_string(length))
        |> put_resp_header("upload-offset", Integer.to_string(offset))

      %{offset: offset} when is_integer(offset) ->
        conn
        |> put_resp_header("upload-offset", Integer.to_string(offset))
    end
    |> send_resp(:ok, "")
  end

  defp disable_caching(conn, _) do
    put_resp_header(conn, "cache-control", "no-store")
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
end
