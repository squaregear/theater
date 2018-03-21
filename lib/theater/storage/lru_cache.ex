defmodule Theater.Storage.LruCache do
  use GenServer

  @moduledoc """
  This is a simple in-memory cache. It is only suitable in a single-node
  setting.

  It is useful for testing and experimentation and doesn't require multiple
  nodes or fancy configuration. It is good for testing your Actors. But it
  doesn't share anything between nodes.

  The reason it won't work in a multi-node setting is that if different nodes
  can get their cache layer out of synch with each other. If two updates come
  in and they are handled by two different servers, then even though they might
  persist to the back end, as long as the Actors remain in cache, they will be
  out of synch with each other.
  """

  @behaviour Theater.Storage

  defstruct map: %{}, first: :nil, last: :nil, max: 1024, size: 0

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Theater.Storage.LruCache)
  end

  def get(module, id) do
    GenServer.call(Theater.Storage.LruCache, {:get, module, id})
  end

  def put(module, id, state, notify) do
    GenServer.cast(Theater.Storage.LruCache, {:put, module, id, state, notify})
  end

  def delete(module, id) do
    GenServer.cast(Theater.Storage.LruCache, {:delete, module, id})
  end

  # Callbacks ################################################

  def init(opts) do
    size=Keyword.get(opts, :size, 1024)
    {:ok, %Theater.Storage.LruCache{max: size}}
  end

  def handle_call({:get, module, id}, _from, cache) do
    {:reply, cache_get(cache, {module, id}), cache}
  end

  def handle_cast({:put, module, id, state, notify}, cache) do
    new_cache=cache_put(cache, {module, id}, state, notify)
    {:noreply, new_cache}
  end
  def handle_cast({:delete, module, id}, cache) do
    new_cache=cache_delete(cache, {module, id})
    {:noreply, new_cache}
  end
  def handle_cast(_, cache), do: {:noreply, cache}

  # Support ##################################################

  defmodule CacheItem do
    @moduledoc """
    Cache items are how values are stored in the cache.
    """

    @doc """
    The CacheItem structure holds a value and pointers to the next and previous
    items in the cache, according to age.
    """
    defstruct value: :nil, prev: :nil, next: :nil
  end

  def cache_get(%Theater.Storage.LruCache{size: 0}, _key) do
    :not_present
  end
  def cache_get(%Theater.Storage.LruCache{}=cache, key) do
    case cache.map[key] do
      :nil ->
        :not_present
      %CacheItem{value: value} ->
        {:ok, value}
    end
  end

  defp cache_put(%Theater.Storage.LruCache{size: 0}=cache, key, value, _notify)
        do
    new_map=Map.put(cache.map, key, %CacheItem{value: value})
    %{cache| map: new_map, first: key, last: key, size: 1}
  end
  defp cache_put(%Theater.Storage.LruCache{last: last, size: size}=cache, key,
        value, notify) do
    case cache.map[key] do
      :nil ->
        old_last=cache.map[cache.last]
        map=cache.map
        |> Map.put(last, %{old_last| next: key})
        |> Map.put(key, %CacheItem{value: value, prev: last})
        prune(%{cache| map: map, last: key, size: size+1}, notify)
      _old_value ->
        cache
        |> cache_delete(key)
        |> cache_put(key, value, notify)
    end
  end

  defp cache_delete(%Theater.Storage.LruCache{}=cache, key) do
    case cache.map[key] do
      :nil ->
        cache
      %CacheItem{prev: prev, next: next} ->
        cache
        |> set_next(prev, next)
        |> set_prev(next, prev)
        |> remove(key)
    end
  end

  defp set_next(%Theater.Storage.LruCache{}=cache, :nil, value) do
    %{cache| first: value}
  end
  defp set_next(%Theater.Storage.LruCache{}=cache, key, value) do
    new_entry=%{cache.map[key]| next: value}
    new_map=Map.put(cache.map, key, new_entry)
    %{cache| map: new_map}
  end

  defp set_prev(%Theater.Storage.LruCache{}=cache, :nil, value) do
    %{cache| last: value}
  end
  defp set_prev(%Theater.Storage.LruCache{}=cache, key, value) do
    new_entry=%{cache.map[key]| prev: value}
    new_map=Map.put(cache.map, key, new_entry)
    %{cache| map: new_map}
  end

  defp remove(%Theater.Storage.LruCache{size: size}=cache, key) do
    new_map=Map.delete(cache.map, key)
    %{cache| map: new_map, size: size-1}
  end

  defp prune(%Theater.Storage.LruCache{size: size, max: max}=cache, notify)
        when size>max do
    first=cache.first
    send(notify, {:removed_from_storage, __MODULE__,
           {first, cache.map[first].value}})
    cache
    |> cache_delete(first)
    |> prune(notify)
  end
  defp prune(%Theater.Storage.LruCache{}=cache, _notify) do
    cache
  end

end
