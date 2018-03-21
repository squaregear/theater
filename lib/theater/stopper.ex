defmodule Theater.Stopper do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def touch(pid) do
    GenServer.cast(__MODULE__, {:touch, pid})
  end

  def mark_as_done(pid) do
    GenServer.cast(__MODULE__, {:remove, pid})
  end

  def clean() do
    GenServer.cast(__MODULE__, :clean)
  end

  # Callbacks ################################################

  def init(_opts) do
    :application.ensure_all_started(:os_mon)
    case :ets.info(__MODULE__, :name) do
      :undefined ->
        :ets.new(__MODULE__, [:named_table])
      _ -> nil
    end
    case :ets.info(__MODULE__.Master, :name) do
      :undefined ->
        :ets.new(__MODULE__.Master, [:named_table])
      _ -> nil
    end

    oldest=lookup(__MODULE__.Master, :oldest, nil)
    newest=lookup(__MODULE__.Master, :newest, nil)

    {:ok, {oldest, newest}}
  end

  def handle_cast({:touch, pid}, {nil, nil}) do
    :ets.insert(__MODULE__, {pid, {nil, nil}})
    :ets.insert(__MODULE__.Master, {:oldest, pid})
    :ets.insert(__MODULE__.Master, {:newest, pid})
    {:noreply, {pid, pid}}
  end
  def handle_cast({:touch, pid}, {oldest, newest}) do
    case :ets.lookup(__MODULE__, pid) do
      [] ->
        :ets.insert(__MODULE__, {pid, {newest, nil}})
        update_newer(newest, pid)
        :ets.insert(__MODULE__.Master, {:newest, pid})
        clean()
        {:noreply, {oldest, pid}}
      _ ->
        {:noreply, state}=handle_cast({:remove, pid}, {oldest, newest})
        handle_cast({:touch, pid}, state)
    end
  end

  def handle_cast({:remove, _pid}, {nil, nil}) do
    {:noreply, {nil, nil}}
  end
  def handle_cast({:remove, pid}, {oldest, newest}=state) do
    case :ets.lookup(__MODULE__, pid) do
      [{^pid, {older, newer}}] ->
        state=state
        |> update_newer(older, newer)
        |> update_older(newer, older)
        :ets.delete(__MODULE__, pid)
        clean()
        {:noreply, state}
      _ ->
        clean()
        {:noreply, {oldest, newest}}
    end
  end

  def handle_cast(:clean, {nil, newest}) do
    {:noreply, {nil, newest}}
  end
  def handle_cast(:clean, {oldest, newest}) do
    mem=:memsup.get_system_memory_data()
    pct=Keyword.get(mem, :free_memory)/Keyword.get(mem, :total_memory)
    if pct<0.2 do
      send(oldest, :stop)
    end
    {:noreply, {oldest, newest}}
  end

  # Support ###############################################

  defp lookup(table, key, default) do
    case :ets.lookup(table, key) do
      [{^key, val}] -> val
      _ -> default
    end
  end

  defp update_newer(pid, newer) do
    [{^pid, {older, _}}]=:ets.lookup(__MODULE__, pid)
    :ets.insert(__MODULE__, {pid, {older, newer}})
  end

  defp update_newer({_, newest}, nil, newer) do
    :ets.insert(__MODULE__.Master, {:oldest, newer})
    {newer, newest}
  end
  defp update_newer({oldest, _}, pid, nil) do
    update_newer(pid, nil)
    :ets.insert(__MODULE__.Master, {:newest, pid})
    {oldest, pid}
  end
  defp update_newer(state, pid, newer) do
    update_newer(pid, newer)
    state
  end

  defp update_older(pid, older) do
    [{^pid, {_, newer}}]=:ets.lookup(__MODULE__, pid)
    :ets.insert(__MODULE__, {pid, {older, newer}})
  end

  defp update_older({oldest, _}, nil, older) do
    :ets.insert(__MODULE__.Master, {:newest, older})
    {oldest, older}
  end
  defp update_older({_, newest}, pid, nil) do
    update_older(pid, nil)
    :ets.insert(__MODULE__.Master, {:oldest, pid})
    {pid, newest}
  end
  defp update_older(state, pid, older) do
    update_older(pid, older)
    state
  end

end
