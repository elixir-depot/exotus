defmodule Exotus.Plug.Options do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _) do
    conn
    |> put_resp_header("tus-max-size", Integer.to_string(conn.private.exotus_config.max_size))
    |> put_resp_header("tus-extension", Enum.join(Exotus.supported_extensions(), ","))
    |> send_resp(:no_content, "")
  end
end
