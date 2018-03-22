defmodule Theater.Storage do
  @moduledoc """
  Defines a persistence storage provider.

  Persistenced providers are responsible for keeping the state of Actors so
  that when they are cleaned out of memory they can be restored to a previously
  saved state.

  Implementations can be generic, designed to store any kind of state. Or they
  can be custom built, with each type of Actor stored in its own database
  table, for instance. You would just have to match on the different module
  types.

  A default storage implementation, `Theater.Storage.MnesiaDisk`, is provided
  with Theater, but it is **not recommended** for actual production use. Mnesia
  has significant issues with scaling, and only exists within the cluster
  itself, which can lead to problems when nodes are added or removed, and in a
  "split brain" scenario it completely defeats the purpose of the persistence
  storage.  It is included only because Mnesia comes in the box with Erlang and
  it is sufficient to play with for understanding how Theater works. Please do
  not consider it anything more than a toy implementation.

  Modules that implement this behaviour must implement all three methods. There
  are no suitable defaults.
  """

  @doc """
  Invoked when a stored Actor state is needed.

  This call should find the state for the indicated type (module) and ID.

  Returning `{:ok, state}` indicates that the Actor's state was found and
  provides it.

  Returning `{:error, reason}` indicates that there was a problem trying to
  retrieve the Actor's state.

  Returning `:not_present` indicates that the Actor's state is not stored. This
  means that the Actor should be created anew with init().
  """
  @callback get(module :: atom, id :: any) ::
        {:ok, state :: any}
        | {:error, reason :: any}
        | :not_present

  @doc """
  Invoked to store an Actor's state.

  Returning `:ok` indicates that the Actor's state was successfully stored.

  Returning `{:error, reason}` indicates that there was an error storing the
  Actor's state. The caller should assume that the Actor's state was not
  persisted.
  """
  @callback put(module :: atom, id :: any, state :: any) ::
        :ok
        | {:error, reason :: any}

  @doc """
  Invoked to remove an Actor's state.

  Returning `:ok` indicates that the Actor's state was successfully removed.

  Returning `{:error, reason}` indicates that there was an error deleting the
  Actor's state. The caller may not assume that the Actor's state was removed.
  """
  @callback delete(module :: atom, id :: any) ::
        :ok
        | {:error, reason :: any}

end
