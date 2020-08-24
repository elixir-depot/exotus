defmodule Exodus.Plug.MethodOverride do
  @behaviour Plug

  @allowed_methods ~w(DELETE PATCH)

  def init([]), do: []

  def call(%Plug.Conn{method: "POST"} = conn, []),
    do: override_method(conn)

  def call(%Plug.Conn{} = conn, []), do: conn

  defp override_method(conn) do
    [method] = Plug.Conn.get_req_header(conn, "x-http-method-override")
    method = String.upcase(method)

    if method in @allowed_methods do
      %{conn | method: method}
    else
      conn
    end
  end
end
