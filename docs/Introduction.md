# Theater

Theater is a simple, scalable, actor-model framework for Elixir.

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
