defmodule Exotus.Registry do
  def child_spec(_) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  @spec get_upload(any) :: :error | {:ok, pid}
  def get_upload(path) do
    case Registry.lookup(__MODULE__, path) do
      [{server, _}] -> {:ok, server}
      _ -> :error
    end
  end

  def register(path) do
    Registry.register(__MODULE__, path, nil)
  end
end
