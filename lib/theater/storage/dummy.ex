defmodule Theater.Storage.Dummy do
  use GenServer

  require Logger

  @behaviour Theater.Storage

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Theater.Storage.Dummy)
  end

  def get(_module, _id) do
    Logger.debug("Dummy get")
    :not_present
  end

  def put(_module, _id, _state) do
    Logger.debug("Dummy put")
    :ok
  end

  def delete(_module, _id) do
    Logger.debug("Dummy delete")
    :ok
  end

  # Callbacks ################################################

  def init(_opts) do
    {:ok, []}
  end

end
