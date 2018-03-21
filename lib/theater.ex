defmodule Theater do
  use GenServer

  alias Theater.Launcher

  @moduledoc """
  Documentation for Theater.
  """

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def send(module, id, message) do
    [{:nodes, node_list}]=:ets.lookup(__MODULE__.State, :nodes)
    node_list
    |> get_target_node(module, id)
    |> launch(module, id, message)
  end

  def reload_nodes(new_node \\ nil) do
    GenServer.cast(__MODULE__, {:reload_nodes, new_node})
  end

  def get_target_node(list, module, id) do
    list
    |> Enum.reduce({nil, 0}, fn(n, acc) -> replace_max(n, acc, module, id) end)
    |> elem(0)
  end

  # Node.connect(:foo@877JWF2)
  # :mnesia.change_config(:extra_db_nodes, Node.list())

  # Callbacks ################################################

  def init(_) do
    :net_kernel.monitor_nodes(true)
    case :ets.info(__MODULE__.State, :name) do
      :undefined ->
        :ets.new(__MODULE__.State, [:named_table, {:write_concurrency, true}])
      _ -> nil
    end
    build_node_list()
    |> Enum.each(&announce_self/1)
    {:ok, nil}
  end

  def handle_cast({:reload_nodes, new_node}, _) do
    build_node_list()
    spawn(fn() -> Launcher.stop_actors_for(new_node) end)
    {:noreply, nil}
  end

  def handle_info({:nodeup, n}, _) do
    # zzz This seems to get here before Theater is running on the other node
    # so do we even do this, since it's going to announce itself anyway?
    IO.puts("(#{node()}) New node: #{n}")
    IO.inspect(Node.list())
    build_node_list()
    {:noreply, nil}
  end
  def handle_info({:nodedown, n}, _) do
    IO.puts("(#{node()}) Lost node: #{n}")
    build_node_list()
    {:noreply, nil}
  end
  def handle_info(_, _) do
    {:noreply, nil}
  end

  # Support ###############################################
  
  defp build_node_list() do
    theater_nodes=[node() | Node.list()]
    |> Enum.filter(fn(n) -> :rpc.call(n, Process, :whereis, [Theater])!=nil end)
    :ets.insert(__MODULE__.State, {:nodes, theater_nodes})
    theater_nodes
  end

  defp announce_self(n) when n==node(), do: nil
  defp announce_self(n) do
    Node.spawn(n, Theater, :reload_nodes, [node()])
  end

  defp replace_max(n, {top, max}, module, id) do
    bin=:erlang.term_to_binary({n, module, id})
    hash=:crypto.hash(:sha256, bin)
    case hash>max do
      true -> {n, hash}
      false -> {top, max}
    end
  end

  defp launch(n, module, id, message) do
    Node.spawn(n, Launcher, :send, [module, id, message])
  end

  # zzz how do you agree on actual cluster membership?
  #   I am handling this in a very naive way. If there is a cluster partition
  #   your data could very easily get out of sync. This will amoun to looking
  #   like undelivered messages.
  # zzz Even with my naive membership plan, I still wonder if it's possible for
  #   two nodes to come up at the same time and both miss each other's existence
  # zzz how do you identify old data and free up that memory?
  # zzz how do you connect mnesia nodes and get them in synch?

end
