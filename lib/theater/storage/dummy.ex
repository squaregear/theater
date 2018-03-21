defmodule Theater.Storage.Dummy do
  @moduledoc """
  A dummy storage implementaion for testing.

  This is a storage implementation that doesn't actually store anything. It is only useful for some testing scenarios. Requests to put or delete things are ignored and requests to get things always return `:not_present`.
  """

  use GenServer

  require Logger

  @behaviour Theater.Storage

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Theater.Storage.Dummy)
  end

  @doc """
  Always returns `:not_present`.
  """
  def get(module, id) do
    Logger.debug("Dummy get {#{inspect(module)}, #{inspect(id)}")
    :not_present
  end

  @doc """
  Logs the request, but otherwise ignores it.
  """
  def put(module, id, _state) do
    Logger.debug("Dummy put {#{inspect(module)}, #{inspect(id)}")
    :ok
  end

  @doc """
  Logs the request, but otherwise ignores it.
  """
  def delete(module, id) do
    Logger.debug("Dummy delete {#{inspect(module)}, #{inspect(id)}")
    :ok
  end

  # Callbacks ################################################

  def init(_opts) do
    {:ok, []}
  end

end
