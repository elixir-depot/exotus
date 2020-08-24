defmodule Exotus.Server do
  @table __MODULE__
  @max_attempts 10
  @temp_env_vars ~w(PLUG_TMPDIR TMPDIR TMP TEMP)s

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    Process.flag(:trap_exit, true)
    tmp = Enum.find_value(@temp_env_vars, "/tmp", &System.get_env/1)
    cwd = Path.join(File.cwd!(), "tmp")
    :ets.new(@table, [:named_table, :public, :set])
    {:ok, [tmp, cwd]}
  end
end
