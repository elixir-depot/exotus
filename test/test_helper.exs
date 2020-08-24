if ExUnit.configuration() |> Keyword.fetch!(:include) |> Enum.member?(:integration) do
  {:ok, _} = Application.ensure_all_started(:wallaby)
  Application.put_env(:wallaby, :base_url, "http://localhost:4001")
  Application.put_env(:wallaby, :screenshot_on_failure, true)
  Application.put_env(:wallaby, :chromedriver, headless: true)

  Plug.Cowboy.http(Exotus.Endpoint, [], port: 4001)
end

ExUnit.start(capture_log: true, exclude: [:integration])
