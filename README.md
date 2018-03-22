# Theater

A simple, scalable actor-model framework for Elixir

The idea is that you implement actors, which have state and functions to
process messages, and then communicate only by passing messages to those
actors. This is how all processes work in Erlang/Elixir, but with Theater you
don't worry about starting the instance or cleaning up after it or which
server it lives on. You just address an actor by its ID and send it a
message. Theater takes care of spawning it. It figures out which node it
should live on and gets the message there. As you add nodes to the cluster or
remove them, Theater takes care of your actor instances, making sure they are
there when you need them.

When memory is needed, Theater will automatically free up old actors that
haven't been used lately. But their state is persisted, so they can spring
back up just as they were if you need them later. You control when their
state is persisted, so for transient changes that don't need to be saved, you
can skip that step.

The idea for this sprang from [Microsoft
Orleans](https://dotnet.github.io/orleans/) which implements the actor model
in C# and does all the housekeeping for you. There is already an Erlang
project to immitate Orleans behavior, called
[erleans](https://github.com/SpaceTime-IoT/erleans). It is more mature than
mine, and designed for massive, global scaling. It uses elements of
[Lasp](https://github.com/lasp-lang/lasp) to manage clusters. I relied on
Erlang's built-in clustering. Erleans implements actors with a very
GenServer-like interface. I aimed for more of a pure actor model with only
message passing for communication and a very simple behaviour for actors to
implement.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `theater` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:theater, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/theater](https://hexdocs.pm/theater).

## Usage

Create Actors by defining modules with the Theater.Actor behaviour. For
convienience, modules can `use Theater.Actor` and have some default
implementations provided for them. Here is an example of a simple Actor that
keeps a counter.

    defmodule Counter do
      use Theater.Actor

      def init(id, message) do
        process(0, id, message)
      end

      def process(i, _id, :increment) do
        {:ok, i+1}
      end
      def process(i, id, {:get, pid}) do
        send(pid, {:counter, id, i})
        {:ok, i}
      end
      def process(_i, _id, :done) do
        :stop
      end

    end

And here is how you might use it.

    Theater.send(Counter, :dogs, :increment)
    Theater.send(Coutner, :cats, :increment)
    Theater.send(Counter, :dogs, :increment)

    Theater.send(Counter, :dogs, {:get, self()})
    Theater.send(Counter, :dogs, :done)

Actors are addressed by their type (module) and ID. IDs can be any term you
want to use, so strings, atoms, and integers are all valid.

You do not have to worry about which node of your cluster they are running on,
or what happens to them when you add or remove nodes to scale your cluster up
and down. Theater takes care of starting and stopping those processes. You just
send messages to your Actors by ID and Theater takes care of the rest.

## Theater Client

To have access to your Actors from a node that is not running Theater itself,
include Theater as a dependency and then add an option like this to your
config.exs:

    config :theater, :client_only, true

Then you will still be able to use `Theater.send()` to send messages to your
Actors, but that node will not host Actors itself. This way some node of your
cluster could host Actors and other could, say, run Phoenix.
