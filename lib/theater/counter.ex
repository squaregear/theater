defmodule Theater.Counter do
  use Theater.Actor

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
