defmodule TheaterTest do
  use ExUnit.Case
  doctest Theater

  test "greets the world" do
    assert Theater.hello() == :world
  end
end
