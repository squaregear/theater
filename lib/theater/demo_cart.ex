defmodule Theater.DemoCart do
  use Theater.Actor

  require Logger

  def init(id, message) do
    process({:open, []}, id, message)
  end

  def process({:open, items}, _id, {:add_item, name, price}) do
    {:ok, {:open, [{name, price} | items]}}
  end
  def process({:open, items}, id, :checkout) do
    Logger.info("Payment accepted for #{id}")
    {:ok, {:shipping_order, items}}
  end
  def process({:open, _items}, id, :cancel) do
    Logger.info("Order #{id} stopped")
    {:stop, :no_persist}
  end
  def process({:shipping_order, items}, id, :pay) do
    Logger.info("Order #{id} shipped")
    {:stop, :persist, {:order_shipped, items}}
  end
  def process({:shipping_order, _items}, id, :cancel) do
    Logger.info("Order #{id} cancelled")
    {:stop, :delete}
  end
  def process({:order_shipped, items}, id, :reopen) do
    Logger.info("Order #{id} reopened")
    {:ok, {:open, items}}
  end
  def process({_, items}, id, :get_total) do
    total=Enum.reduce(items, 0, &(elem(&1, 1)+&2))
    Logger.info("Order #{id} total: #{total}")
    :no_update
  end
  def process({_, items}, id, :list) do
    Logger.info("Order #{id}: #{inspect(items)}")
    :no_update
  end

end
