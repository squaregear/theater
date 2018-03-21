defmodule Theater.Actor do

  alias Theater.Stopper

  # Behavior ##############################################

  @callback init(id :: any, message :: any) ::
    {:ok, state :: any}
    | :no_update
    | :stop
    | {:ok, :persist, state :: any}
    | {:ok, :no_persist, state :: any}
    | {:stop, :persist, state :: any}
    | {:stop, :no_persist}
    | {:stop, :delete}

  @callback process(state :: any, id :: any, message :: any) ::
    {:ok, state :: any}
    | :no_update
    | :stop
    | {:ok, :persist, state :: any}
    | {:ok, :no_persist, state :: any}
    | {:stop, :persist, state :: any}
    | {:stop, :no_persist}
    | {:stop, :delete}

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

  def start(module, id, message, persister) do
    spawn(__MODULE__, :init, [module, id, message, persister])
  end

  def start_link(module, id, message, persister) do
    spawn_link(__MODULE__, :init, [module, id, message, persister])
  end

  def process(pid, id, message), do: send(pid, {:process, id, message})

  def stop(pid), do: send(pid, :stop)

  # Support ###############################################

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
