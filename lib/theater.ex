defmodule Theater do
  @moduledoc """
  This is the main module through which you send messages to actors.
  """

  use GenServer

  alias Theater.Launcher

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Send `message` to an actor.

  `module` must be the name of a module that implements the `Theater.Actor`
  behavior. `id` is any term that you want to use to identify the actor to
  receive the message. Actors are identified by {module, id} pairs, so actors
  of different `module` types can have the same `id`.
  """
  def send(module, id, message) do
    [{:nodes, node_list}]=:ets.lookup(__MODULE__.State, :nodes)
    node_list
    |> get_target_node(module, id)
    |> launch(module, id, message)
  end

  @doc false
  def reload_nodes(new_node \\ nil) do
    GenServer.cast(__MODULE__, {:reload_nodes, new_node})
  end

  @doc """
  Gets the node from `list` that an actor of type `module` with `id` should
  live on.
  """
  def get_target_node(list, module, id) do
    list
    |> Enum.reduce({nil, 0}, fn(n, acc) -> replace_max(n, acc, module, id) end)
    |> elem(0)
  end

  # Node.connect(:foo@877JWF2)
  # :mnesia.change_config(:extra_db_nodes, Node.list())

  # Callbacks ################################################

  def init(is_server) do
    :net_kernel.monitor_nodes(true)
    case :ets.info(__MODULE__.State, :name) do
      :undefined ->
        :ets.new(__MODULE__.State, [:named_table, {:write_concurrency, true}])
      _ -> nil
    end
    build_node_list()
    |> Enum.each(&announce_self/1)
    {:ok, is_server}
  end

  def handle_cast({:reload_nodes, new_node}, is_server) do
    build_node_list()
    if is_server do
      spawn(fn() -> Launcher.stop_actors_for(new_node) end)
    end
    {:noreply, is_server}
  end

  def handle_info({:nodeup, n}, is_server) do
    # zzz This seems to get here before Theater is running on the other node
    # so do we even do this, since it's going to announce itself anyway?
    build_node_list()
    if is_server do
      announce_self(n)
    end
    {:noreply, is_server}
  end
  def handle_info({:nodedown, _n}, is_server) do
    build_node_list()
    {:noreply, is_server}
  end
  def handle_info(_, is_server) do
    {:noreply, is_server}
  end

  # Support ###############################################
  
  defp build_node_list() do
    theater_nodes=[node() | Node.list()]
    |> Enum.filter(fn(n) ->
      :rpc.call(n, Process, :whereis, [Theater.Launcher])!=nil
    end)
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
