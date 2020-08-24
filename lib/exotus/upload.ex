defmodule Exotus.Upload do
  use GenStateMachine

  def start_link(inital_data) do
    GenStateMachine.start_link(__MODULE__, inital_data)
  end

  def append(server, offset, iodata) do
    GenStateMachine.call(server, {:append, offset, iodata})
  end

  def status(server) do
    GenServer.call(server, :get_status)
  end

  @impl GenStateMachine
  def init(inital_data) do
    path = Plug.Upload.random_file!("tus")

    data = %{
      id: Map.fetch!(inital_data, :id),
      path: path,
      content_length: Map.fetch!(inital_data, :content_length),
      upload_offset: 0,
      metadata: Map.get(inital_data, :metadata, %{})
    }

    Exotus.Registry.register(data.id)

    {:ok, :listening, data}
  end

  # Callbacks
  @impl GenStateMachine
  def handle_event({:call, from}, :get_id, _state, data) do
    {:keep_state_and_data, [{:reply, from, data.id}]}
  end

  def handle_event({:call, from}, :get_status, _state, data) do
    status = %{
      length: data.content_length,
      offset: data.upload_offset
    }

    {:keep_state_and_data, [{:reply, from, status}]}
  end

  def handle_event({:call, from}, {:append, offset, iodata}, _state, data) do
    with :ok <- match_offset(data.upload_offset, offset),
         {:ok, new_offset} <- new_offset(data.upload_offset, iodata, data.content_length),
         :ok <- write_file(data.path, iodata) do
      {:keep_state, Map.put(data, :upload_offset, new_offset),
       [{:reply, from, {:ok, new_offset}}]}
    else
      :file_size_exceeded ->
        {:keep_state_and_data, [{:reply, from, {:error, :file_size_exceeded}}]}

      :file_write_error ->
        {:keep_state_and_data, [{:reply, from, {:error, :file_write_error}}]}

      :offset_mismatch ->
        {:keep_state_and_data, [{:reply, from, {:error, :offset_mismatch}}]}
    end
  end

  defp match_offset(current, append) do
    if current == append do
      :ok
    else
      :offset_mismatch
    end
  end

  defp new_offset(current, iodata, allowed) do
    new = current + IO.iodata_length(iodata)
    if new <= allowed, do: {:ok, new}, else: :file_size_exceeded
  end

  defp write_file(file, iodata) do
    case File.write(file, iodata) do
      :ok -> :ok
      _ -> :file_write_error
    end
  end

  # @impl GenServer
  # def handle_call({:append, file}, _from, state) do
  #   {:ok, source} = File.open(file, [:read, :binary, :raw])
  #   {:ok, destination} = File.open(state.path, [:append, :binary, :delayed_write, :raw])

  #   IO.binwrite(destination, IO.binread(source, :all))

  #   :ok = File.close(source)
  #   :ok = File.close(destination)

  #   {:reply, :ok, state}
  # end
end
