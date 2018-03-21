defmodule Theater.Launcher do
  use GenServer

  alias Theater.Actor

  def start_link(persister) do
    GenServer.start_link(__MODULE__, persister, name: __MODULE__)
  end

  def send(module, id, message) do
    case send_if_present(module, id, message) do
      :ok -> :ok
      :nil -> GenServer.cast(__MODULE__, {:launch, module, id, message})
    end
  end

  def stop_actors_for(node) do
    :ets.foldl(fn({key, pid}, _) ->
        remove_if_remote(key, pid, node)
    end, nil, __MODULE__)
  end

  # Callbacks ################################################

  def init(persister) do
    Process.flag(:trap_exit, true)
    case :ets.info(__MODULE__, :name) do
      :undefined ->
        :ets.new(__MODULE__, [:named_table, {:write_concurrency, true}])
      _ -> nil
    end
    case :ets.info(__MODULE__.Reverse, :name) do
      :undefined ->
        :ets.new(__MODULE__.Reverse, [:named_table])
      _ -> nil
    end
    {:ok, persister}
  end

  def handle_cast({:launch, module, id, message}, persister) do
    case send_if_present(module, id, message) do
      :ok -> :ok
      :nil -> launch(module, id, message, persister)
    end
    {:noreply, persister}
  end

  def handle_info({:EXIT, pid, _reason}, persister) do
    case :ets.lookup(__MODULE__.Reverse, pid) do
      [{^pid, id}] ->
        :ets.delete(__MODULE__.Reverse, pid)
        case :ets.lookup(__MODULE__, id) do
          [{^id, _}] -> :ets.delete(__MODULE__, id)
          _ -> nil
        end
      _ -> nil
    end
    {:noreply, persister}
  end
  def handle_info(_, persister) do
    {:noreply, persister}
  end

  # Support ###############################################

  defp send_if_present(module, id, message) do
    case :ets.lookup(__MODULE__, {module, id}) do
      [{_, pid}] ->
        send_if_running(pid, id, message)
        :ok
      _ -> nil
    end
  end

  # It is possible for a process to end between checking for alive and calling
  # Actor.process(). In that case it will neither get the message nor launch a
  # new instance of it.
  defp send_if_running(pid, id, message) do
    case Process.alive?(pid) do
      true -> Actor.process(pid, id, message)
      false -> nil
    end
  end

  defp launch(module, id, message, persister) do
    pid=Actor.start_link(module, id, message, persister)
    :ets.insert(__MODULE__, {{module, id}, pid})
    :ets.insert(__MODULE__.Reverse, {pid, {module, id}})
  end

  defp remove_if_remote({module, id}, pid, node) do
    case Theater.get_target_node([node, node()], module,  id) do
      ^node ->
        Actor.stop(pid)
      _ -> nil
    end
  end

end
