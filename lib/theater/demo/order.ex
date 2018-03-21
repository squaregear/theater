defmodule Theater.Demo.Order do
  @moduledoc """
  A more complex demonstration Actor.

  This is a simple actor for demonstrating how implementing an Actor works. It
  represents an order and goes through several stages like a state machine. It
  can also interact with other Actors.

  Items can be added to an order and when payment is received the order is
  closed and ready for shipping. Once an order is shipped it is done and we
  close it. The cutomer name can be set at any point, and can be copied to
  another order.

  When Actors get a new message they will process it with `process/3`. They
  will be passed the current state of the Actor, the ID that was used to reach
  this Actor, and the message being passed to it. The Actor is responsible for
  processing any messages sent to it and returning a value indicating its new
  state and whether to persist it. See `Theater.Actor` for further
  documentation.
  """

  use Theater.Actor

  @doc """
  Create a new order.

  Orders start with no items and no customer name, but then process messages as
  normal.
  """
  def init(id, {:get, pid}) do
    send(pid, {:order, id, :no_such_order})
    :stop
  end
  def init(id, message) do
    process({:open, [], nil}, id, message)
  end

  @doc """
  Process a message for a Counter.

  Sending `{:add, item}` will add `item` to the order.

  Sending `:pay` will stop accepting items and mark it ready to be shipped if
  it is open.

  Sending `:ship` will close out the order if it is ready to be shipped.

  Sending `{:set_name, name}` will set the customer name to `name`.

  Sending `{:copy_name_to, id}` will copy the customer name from this order to
  order `id`.

  Sending `{:get, pid}` will send a message to pid of the form `{:order, id,
  items, name}`.
  """
  def process({_state, items, name}, id, {:get, pid}) do
    send(pid, {:order, id, items, name})
    :no_update
  end
  def process({state, items, _}, _id, {:set_name, name}) do
    {:ok, {state, items, name}}
  end
  def process({_state, _items, name}, _id, {:copy_name_to, id}) do
    Theater.send(__MODULE__, id, {:set_name, name})
    :no_update
  end
  def process({:open, items, name}, _id, {:add, item}) do
    {:ok, {:open, [item | items], name}}
  end
  def process({:open, items, name}, _id, :pay) do
    {:ok, {:ready_to_ship, items, name}}
  end
  def process({:ready_to_ship, _items, _name}, _id, :ship) do
    :stop
  end

end
