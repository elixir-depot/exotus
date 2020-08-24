defmodule Exotus do
  @moduledoc """
  Documentation for `Exotus`.
  """

  @doc """
  Lists the supported tus protocol versions.

  ## Example

      iex> Exotus.supported_versions()
      ["1.0.0"]

  """
  def supported_versions do
    ["1.0.0"]
  end

  @doc """
  Lists the supported tus extensions.

  ## Example

      iex> Exotus.supported_extensions()
      []

  """
  def supported_extensions do
    []
  end
end
