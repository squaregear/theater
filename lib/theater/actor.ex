defmodule Theater.Actor do
  @moduledoc """
  Defines an Actor.
  
  An Actor defines an entity in your system, like an order or a logged in user.
  It can have state. You interact with an Actor by sending it messages.
  
  Instances of your Actor are identified by their type (its module name) and an
  ID. IDs can be any term and can vary with each type. So one type of actor in
  your system can use string names, and another can use integer IDs. Actors are
  uniquely identified by a combination of their type and ID, so Actors of
  different types can safely have the same ID.

  Actors can be instantiated anywhere on your Theater cluster. You don't need
  to worry about where they are. If memory is needed, old Actors will be
  cleared out, but if they have been persisted they can be pulled back up later
  as if they were never gone.

  ## Example

  Here is an example of a simple Actor that keeps a counter.

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

  ## Persisting
  
  After processing a message, Actors return a value indicating whether and how
  to maintain their state. State is kept at two levels: in memory and in a
  persistence layer.

  State is kept in memory for quick retrieval. Normally, an Actor is kept
  present in memory until space is needed. But if after processing a message
  you know that the Actor's work is done, or it won't be needed for a while,
  you can return a value indicating that it is safe to stop the Actor process
  and free up its memory. It's also possible to indicate that the Actor's
  state shouldn't change. This is useful for messages that only read the
  state and don't update anything.

  Whether an Actor is stopped manually or automatically, its state can be
  recreated depending on how it was saved to the persistence layer. When an
  Actor is instatiated its state will reflect whatever was the last state to be
  persisted. You indicate whether to persist or not with the return value after
  processing a message. In most cases you will want to persist your changes.
  Otherwise they will be lost if the Actor happens to get cleaned up, or if
  its instance gets moved to a new node in the cluster. But sometimes a
  message doesn't cause any changes, or changes that are transient and
  recreatable. In those cases it's more efficient to skip persisting the
  Actor's state.

  For more information on the return values that control persistence see the
  `init/2` and `process/3` callbacks.

  ## use Theater.Actor and callbacks

  There are three callbacks required in an Actor. By adding `use Theater.Actor`
  to your module, Elixir will automatically define all three for you, leaving
  it up to you to implement only the ones you want to customize.

  You probably want to implement `process/3`, since that is the one that does
  all the work of your Actor. 

  If you don't implement your own `init/2` you can expect to see
  newly-instantiated Actors hit `process/3` with a `state` of `nil`.
  """

  alias Theater.Stopper

  # Behavior ##############################################

  @doc """
  Invoked when a specific instance of this Actor is first instantiated.

  Instance `id` is being created and sent `message`.

  Returning `{:ok, state}` or `{:ok, :persist, state}` will update the Actor's
  `state`, keep it running in memory, and save it in the persistence layer.

  Returning `{:ok, :no_persist, state}` will update the Actor's `state` and
  keep it in memory, but will not save it to the persistence layer. These
  changes could be lost if the Actor is stopped or moved to another node.

  Returning `:no_update` will keep the Actor in memory, but will not record any
  changes to its state.

  Returning `:stop` or `{:stop, :delete}` will stop the Actor, free up its
  memory, and delete it from the persistence layer. Future messages to this
  Actor ID will create a brand new Actor as though it didn't already exist.

  Returning `{:stop, :persist, state}` will stop the Actor and free up its
  memory, but will record `state` to the persistence layer. Future calls to
  this Actor ID will recreate it from this `state`.

  Returning `{:stop, :no_persist}` will stop the Actor and free up its memory.
  No change will be made in the persistence layer, whether it exists or not. 
  """
  @callback init(id :: any, message :: any) ::
    {:ok, state :: any}
    | :no_update
    | :stop
    | {:ok, :persist, state :: any}
    | {:ok, :no_persist, state :: any}
    | {:stop, :persist, state :: any}
    | {:stop, :no_persist}
    | {:stop, :delete}

  @doc """
  Invoked when a message is received by an Actor.

  Instance `id` with a current `state` is receiving `message`.

  Returning `{:ok, state}` or `{:ok, :persist, state}` will update the Actor's
  `state`, keep it running in memory, and save it in the persistence layer.

  Returning `{:ok, :no_persist, state}` will update the Actor's `state` and
  keep it in memory, but will not save it to the persistence layer. These
  changes could be lost if the Actor is stopped or moved to another node.

  Returning `:no_update` will keep the Actor in memory, but will not record any
  changes to its state.

  Returning `:stop` or `{:stop, :delete}` will stop the Actor, free up its
  memory, and delete it from the persistence layer. Future messages to this
  Actor ID will create a brand new Actor as though it didn't already exist.

  Returning `{:stop, :persist, state}` will stop the Actor and free up its
  memory, but will record `state` to the persistence layer. Future calls to
  this Actor ID will recreate it from this `state`.

  Returning `{:stop, :no_persist}` will stop the Actor and free up its memory.
  No change will be made in the persistence layer, whether it exists or not. 
  """
  @callback process(state :: any, id :: any, message :: any) ::
    {:ok, state :: any}
    | :no_update
    | :stop
    | {:ok, :persist, state :: any}
    | {:ok, :no_persist, state :: any}
    | {:stop, :persist, state :: any}
    | {:stop, :no_persist}
    | {:stop, :delete}

  @doc """
  Invoked to determine how long the Actor should live without receiving any
  messages.

  If, after this amount of time, the Actor has received no messages, it will be
  considered unneeded, it will be stopped, and its memory freed up. Any state
  that has not been persisted will be lost.

  The result can depend on the Actor's `id` and/or `state` or it can simply
  return a constant. Return value should be time to live in milliseconds.

  If this callback is not implemented, the default implementation by `use
  Theater.Actor` will a value configurable under :theater,
  :default_time_to_live. If no value is configured, it will return ten minutes.
  """
  @callback time_to_live(state :: any, id :: any) :: integer

  # zzz give an actor a chance to do something before we shut it down?
  # This isn't guaranteed to happen (errors, node crash, etc).

  defmacro __using__(_opts) do
    quote do
      @behaviour Theater.Actor
  
      @ttl Application.get_env(:theater, :default_time_to_live, 600_000)

      def init(id, message) do
        process(:nil, id, message)
      end

      def process(_state, _id, _message) do
        :no_update
      end

      def time_to_live(_state, _id) do
        @ttl
      end

      defoverridable Theater.Actor
    end
  end

  # API ###################################################

  @doc false
  def start(module, id, message, persister) do
    spawn(__MODULE__, :init, [module, id, message, persister])
  end

  @doc false
  def start_link(module, id, message, persister) do
    spawn_link(__MODULE__, :init, [module, id, message, persister])
  end

  @doc false
  def process(pid, id, message), do: send(pid, {:process, id, message})

  @doc false
  def stop(pid), do: send(pid, :stop)

  # Support ###############################################

  @doc false
  def init(module, id, message, persister) do
    Stopper.touch(self())
    persister.get(module, id)
    |> init(module, id, message, persister)
  end

  defp init({:ok, state}, module, id, message, persister) do
    module.process(state, id, message)
    |> handle_result(module, id, state, persister)
  end
  defp init(:not_present, module, id, message, persister) do
    module.init(id, message)
    |> translate_start_result()
    |> handle_result(module, id, nil, persister)
  end
  # zzz what do we do if the get() failed?

  defp loop(module, id, state, persister) do
    receive do
      {:process, id, message} ->
        Stopper.touch(self())
        module.process(state, id, message)
        |> handle_result(module, id, state, persister)
      :stop ->
        Stopper.mark_as_done(self())
      _ ->
        loop(module, id, state, persister)
    after
      module.time_to_live(state, id) ->
        Stopper.mark_as_done(self())
    end
  end

  defp translate_start_result(:no_update), do: {:stop, :no_persist}
  defp translate_start_result(result), do: result

  defp handle_result({:ok, new_state}, module, id, state, persister) do
    handle_result({:ok, :persist, new_state}, module, id, state, persister)
  end
  defp handle_result(:no_update, module, id, state, persister) do
    loop(module, id, state, persister)
  end
  defp handle_result(:stop, module, id, state, persister) do
    handle_result({:stop, :delete}, module, id, state, persister)
  end
  defp handle_result({:ok, :persist, new_state}, module, id, _, persister) do
    persister.put(module, id, new_state)
    loop(module, id, new_state, persister)
  end
  defp handle_result({:ok, :no_persist, new_state}, module, id, _, persister) do
    loop(module, id, new_state, persister)
  end
  defp handle_result({:stop, :persist, new_state}, module, id, _, persister) do
    persister.put(module, id, new_state)
    Stopper.mark_as_done(self())
  end
  defp handle_result({:stop, :no_persist}, _module, _id, _, _persister) do
    Stopper.mark_as_done(self())
  end
  defp handle_result({:stop, :delete}, module, id, _, persister) do
    persister.delete(module, id)
    Stopper.mark_as_done(self())
  end

end
