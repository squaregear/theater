defmodule Theater.Storage.MnesiaDisk do
  @moduledoc """
  A simple Mnesia storage implementation for experimenting.

  This is a very simple storage implementation provided for out-of-the-box
  experimental usage. It is **not recommended** for actual production use.
  Mnesia has significant issues with scaling, and only exists within the
  cluster itself, which can lead to problems when nodes are added or removed,
  and in a "split brain" scenario it completely defeats the purpose of the
  persistence storage.  It is included only because Mnesia comes in the box
  with Erlang and it is sufficient to play with for understanding how Theater
  works. Please do not consider it anything more than a toy implementation.
  """

  use GenServer

  require Logger

  @behaviour Theater.Storage

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Retrieves the state of the given Actor.
  """
  def get(module, id) do
    case :mnesia.dirty_read({__MODULE__, {module, id}}) do
      [] -> :not_present
      [{__MODULE__, {^module, ^id}, state} | _list] -> {:ok, state}
      other -> {:error, other}
    end
  end

  @doc """
  Stores the state of the given Actor.
  """
  def put(module, id, state) do
    :mnesia.dirty_write({__MODULE__, {module, id}, state})
    # zzz what happens if this fails?
    :ok
  end

  @doc """
  Removes the Actor's state.
  """
  def delete(module, id) do
    :mnesia.dirty_delete({__MODULE__, {module, id}})
    # zzz what happens if this fails?
    :ok
  end

  # Callbacks ################################################

  @doc false
  def init(_opts) do
    :mnesia.start()
    schema_on_disk()
    :mnesia.system_info(:local_tables)
    |> Enum.any?(&(&1==__MODULE__))
    |> create_local()
    :mnesia.table_info(__MODULE__, :disc_copies)
    |> Enum.any?(&(&1==node()))
    |> write_to_disk()
    {:ok, []}
  end

  # Support ##################################################

  defstruct key: :nil, val: :nil

  @doc false
  defmodule Item do
    defstruct key: :nil, val: :nil
  end

  defp schema_on_disk() do
    case :mnesia.table_info(:schema, :storage_type) do
      :ram_copies ->
        :mnesia.change_table_copy_type(:schema, node(), :disc_copies)
      _ ->
        nil
    end
  end

  defp create_local(:false) do
    case :mnesia.system_info(:tables) |> Enum.any?(&(&1==__MODULE__)) do
      true ->
        Logger.debug("#{inspect(__MODULE__)} found remote")
        :mnesia.add_table_copy(__MODULE__, node(), :disc_copies)
      _ ->
        Logger.debug("#{inspect(__MODULE__)} being created")
        :mnesia.create_table(__MODULE__, disc_copies: [node() | Node.list()])
    end
  end
  defp create_local(_) do
    Logger.debug("#{inspect(__MODULE__)} exists locally")
  end

  defp write_to_disk(false) do
    Logger.debug("writing #{inspect(__MODULE__)} to disk")
    :mnesia.change_table_copy_type(__MODULE__, node(), :disc_copies)
  end
  defp write_to_disk(_) do
    Logger.debug("#{inspect(__MODULE__)} is already on disk")
  end

  # Mnesia Notes:
  # You can't push a table to disk unless the schema is on disk
  # Putting the schema on disk (or any other table) generates a unique cookie for it.
  # You can't connect with :mnesia.change_config(:extra_db_nodes, Node.list()) if schemas on disk don't match
  # If schema is :ram_copies then you can connect to other nodes no problem.
  # But, it cookies for other table don't match, either on disc or ram, the connect will fail.
  # If connect failed because of mismatched schema cookie, you can del_table_copy() everything that is on disk, change_table_copy_type(:schema, node(), :ram_copies), then connect, then change the schema back to disc.

end
