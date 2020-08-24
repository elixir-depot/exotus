defmodule ExotusTest do
  use ExUnit.Case
  doctest Exotus

  test "upload" do
    {:ok, pid} = start_supervised({Exotus.Upload, %{content_length: 1024}})
    path = GenServer.call(pid, :get_path)

    "temp.txt"
    |> File.stream!([], 512)
    |> Enum.each(fn part ->
      IO.inspect("hi")
      :ok = File.write("tmp", part)
      Exotus.Upload.append(pid, "tmp")
    end)

    File.rm!("tmp")

    File.read!(path) |> IO.puts()
  end
end
