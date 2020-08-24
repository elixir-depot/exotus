defmodule Exotus.Metadata do
  @moduledoc """
  Handle encoding to and from the `Upload-Metadata` header.
  """

  @type t :: %{optional(String.t() | atom) => String.t()}
  @type header :: String.t()

  @doc """
  Parse header content.

  ## Example

      iex> Exotus.Metadata.parse("filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,is_confidential")
      {:ok, %{"filename" => "world_domination_plan.pdf", "is_confidential" => :empty}}
      iex> Exotus.Metadata.parse("filename not_encoded,is_confidential")
      :error

  """
  @spec parse(header) :: {:ok, t} | :error
  def parse(header) when is_binary(header) and byte_size(header) > 0 do
    header
    |> String.split(",")
    |> Enum.reduce_while(%{}, fn key_value, acc ->
      with [key, value] <- String.split(key_value, " ", trim: true),
           {:ok, value} <- Base.decode64(value) do
        {:cont, Map.put(acc, key, value)}
      else
        [key] -> {:cont, Map.put(acc, key, :empty)}
        _ -> {:halt, :error}
      end
    end)
    |> case do
      map when is_map(map) -> {:ok, map}
      :error -> :error
    end
  end

  def parse(""), do: {:ok, %{}}

  @doc """
  Parse header content.

  ## Example

      iex> Exotus.Metadata.encode(%{"filename" => "world_domination_plan.pdf", "is_confidential" => :empty})
      "filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,is_confidential"

  """
  @spec encode(t) :: header
  def encode(map) do
    for {key, value} when is_binary(key) and (is_binary(value) or value == :empty) <- map do
      case value do
        :empty -> "#{key}"
        value -> "#{key} #{Base.encode64(value)}"
      end
    end
    |> Enum.join(",")
  end
end
