defmodule Exotus.Plug.Head do
  @moduledoc false
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
    %{offset: offset} = status = Exotus.Upload.status(conn.assigns.file)

    Enum.reduce(status, conn, fn
      {:length, length}, conn when is_integer(length) ->
        put_resp_header(conn, "upload-length", Integer.to_string(length))

      {:length, :deferred}, conn ->
        put_resp_header(conn, "upload-defer-length", "1")

      {:metadata, meta}, conn when byte_size(meta) > 0 ->
        put_resp_header(conn, "upload-metadata", meta)

      _, conn ->
        conn
    end)
    |> put_resp_header("upload-offset", Integer.to_string(offset))
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
