defmodule Theater.Storage do

  @callback get(module :: atom, id :: any) ::
        {:ok, state :: any}
        | {:error, reason :: any}
        | :not_present

  @callback put(module :: atom, id :: any, state :: any) ::
        :ok
        | {:error, reason :: any}

  @callback delete(module :: atom, id :: any) ::
        :ok
        | {:error, reason :: any}

end
