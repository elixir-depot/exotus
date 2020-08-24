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
      ["creation", "creation-defer-length"]

  """
  def supported_extensions do
    ["creation", "creation-defer-length"]
  end
end
