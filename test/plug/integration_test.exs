defmodule Exotus.IntegrationTest do
  use ExUnit.Case, async: true
  use Wallaby.Feature

  @moduletag :integration

  feature "users have names", %{session: session} do
    session =
      session
      |> visit("/")
      |> set_value(Query.css("#input"), Path.absname("test/static/img.jpg"))
      |> assert_has(Query.css("#header", text: "DONE"))

    id =
      text(session, Query.css("#url"))
      |> String.replace_prefix("http://localhost:4001/files/", "")

    assert {:ok, file} = Exotus.Registry.get_upload(id)
    assert %{offset: num, length: num} = Exotus.Upload.status(file)
  end
end
