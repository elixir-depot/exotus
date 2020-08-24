defmodule Exotus.Plug.Router do
  use Plug.Router

  def init(opts) do
    max_size = Keyword.get(opts, :max_size, 5 * 1024 * 1024)

    unless is_integer(max_size) and max_size > 0 do
      raise "`max_size` must be a positive integer"
    end

    %{max_size: max_size}
  end

  def call(conn, config) do
    conn
    |> put_private(:exotus_config, config)
    |> super([])
  end

  plug Plug.Head
  plug :match
  plug :match_protocol_version, Exotus.supported_versions()
  plug :dispatch

  options "/" do
    Exotus.Plug.Options.call(conn, [])
  end

  get "*file_path" do
    Exotus.Plug.Head.call(conn, file_path)
  end

  patch "*file_path" do
    Exotus.Plug.Patch.call(conn, file_path)
  end

  match _ do
    send_resp(conn, 400, "")
  end

  defp match_protocol_version(conn, versions) do
    conn = put_resp_header(conn, "tus-version", Enum.join(versions, ","))

    with :protocol_matching <- protocol_matching_type(conn),
         {:ok, requested_version} <- requested_protocol_version(conn),
         {:ok, matched_version} <- find_matching_protocol_version(requested_version, versions) do
      put_resp_header(conn, "tus-resumable", to_string(matched_version))
    else
      :no_protocol_matching_required ->
        conn

      :invalid_protocol_version_requested ->
        conn |> send_resp(:precondition_failed, "") |> halt()

      :no_matching_protocol_version ->
        conn |> send_resp(:precondition_failed, "") |> halt()
    end
  end

  defp protocol_matching_type(%{method: "OPTIONS"}), do: :no_protocol_matching_required
  defp protocol_matching_type(_), do: :protocol_matching

  defp requested_protocol_version(conn) do
    with [version] <- get_req_header(conn, "tus-resumable"),
         {:ok, version} <- Version.parse(version) do
      {:ok, version}
    else
      _ -> :invalid_protocol_version_requested
    end
  end

  defp find_matching_protocol_version(version, available_versions) do
    if Enum.any?(available_versions, &(Version.compare(version, &1) == :eq)) do
      {:ok, version}
    else
      :no_matching_protocol_version
    end
  end
end
