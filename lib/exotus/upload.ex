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
      metadata: Map.get(inital_data, :metadata, "")
    }

    Exotus.Registry.register(data.id)

    {:ok, :waiting, data, [chunk_timeout(), upload_timeout()]}
  end

  # Callbacks
  @impl GenStateMachine

  # Handle appending new chunks (only when still waiting)
  def handle_event({:call, from}, {:append, offset, iodata}, :waiting, data) do
    with :ok <- match_offset(data.upload_offset, offset),
         {:ok, new_offset} <- new_offset(data.upload_offset, iodata, data.content_length),
         :ok <- write_file(data.path, iodata) do
      if new_offset == data.content_length do
        {:next_state, :complete, Map.put(data, :upload_offset, new_offset),
         [{:reply, from, {:ok, new_offset}}, retention_timeout()]}
      else
        {:keep_state, Map.put(data, :upload_offset, new_offset),
         [{:reply, from, {:ok, new_offset}}, chunk_timeout()]}
      end
    else
      :file_size_exceeded ->
        {:keep_state_and_data, [{:reply, from, {:error, :file_size_exceeded}}, chunk_timeout()]}

      :file_write_error ->
        {:keep_state_and_data, [{:reply, from, {:error, :file_write_error}}, chunk_timeout()]}

      :offset_mismatch ->
        {:keep_state_and_data, [{:reply, from, {:error, :offset_mismatch}}, chunk_timeout()]}
    end
  end

  # Call :get_id
  def handle_event({:call, from}, :get_id, _state, data) do
    {:keep_state_and_data, [{:reply, from, data.id}]}
  end

  # Call :get_status
  def handle_event({:call, from}, :get_status, _state, data) do
    status = %{
      length: data.content_length,
      offset: data.upload_offset,
      metadata: data.metadata
    }

    {:keep_state_and_data, [{:reply, from, status}]}
  end

  # Stop if chunks don't come in within reasonable time
  def handle_event(:timeout, :stop_waiting, :waiting, _data) do
    {:stop, :normal}
  end

  # Stop if the whole file is not uploaded in within reasonable time
  def handle_event(:state_timeout, :stop_waiting, :waiting, _data) do
    {:stop, :normal}
  end

  # Stop if file was retained for a certain amount of time
  def handle_event(:state_timeout, :cleanup, :complete, _data) do
    {:stop, :normal}
  end

  # Timeouts
  # TODO make configurable
  defp chunk_timeout do
    {:timeout, :timer.seconds(10), :stop_waiting}
  end

  defp upload_timeout do
    {:state_timeout, :timer.hours(1), :stop_waiting}
  end

  defp retention_timeout do
    {:state_timeout, :timer.hours(24), :cleanup}
  end

  # Helpers
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
end
