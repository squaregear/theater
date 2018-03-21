defmodule Theater.Demo.Counter do
  @moduledoc """
  A simple demonstration Actor.

  This is a simple actor for demonstrating how implementing an Actor works. It
  is a counter. Counters start at 0 and can be incremented. You can send the
  current value to a pid, or mark a counter as done and ready to be removed.

  When Actors get a new message they will process it with `process/3`. They
  will be passed the current state of the Actor, the ID that was used to reach
  this Actor, and the message being passed to it. The Actor is responsible for
  processing any messages sent to it and returning a value indicating its new
  state and whether to persist it. See `Theater.Actor` for further
  documentation.
  """

  use Theater.Actor

  @doc """
  Process a message for a Counter.

  New Counters start at 0.

  Sending `:increment` will increment the counter's value.

  Sending `{:get, pid}` will send a message to pid of the form `{:counter, id,
  value}`.

  Sending `:done` will stop the counter.
  """
  def process(:nil, id, message) do
    process(0, id, message)
  end
  def process(i, id, {:get, pid}) do
    send(pid, {:counter, id, i})
    {:ok, i}
  end
  def process(i, _id, :increment) do
    {:ok, i+1}
  end
  def process(_i, _id, :done) do
    :stop
  end

end
