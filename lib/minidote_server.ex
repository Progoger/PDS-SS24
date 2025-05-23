defmodule Minidote.Server do
  use GenServer
  require Logger
  @moduledoc """
  The API documentation for `Minidote.Server`.
  """

  def start_link(server_name) do
    # if you need arguments for initialization, change here
    GenServer.start_link(Minidote.Server, [], name: server_name)
  end

  def init(_) do
    {:ok, causal_broadcast} = CausalBroadcastWaiting.start_link(:minidote, self())
    # the state of the GenServer is: tuple of link_layer and respond_to
    {:ok, %{objects: %{}, vc: Vectorclock.new(), cb: causal_broadcast, waiting: :sets.new}}
  end

  def handle_call({:read_objects, objects, clock}, _from, state) do
    if clock != :ignore && !Vectorclock.leq(clock, state[:vc]) do
      {:noreply, state}
    else
      readed = read_objects(objects, state[:objects])
      {:reply, {:ok, readed, state[:vc], state[:waiting]}, state}
    end

  end

  def handle_call({:update_objects, updates, clock}, _from, state) do
    if clock != :ignore && !Vectorclock.leq(clock, state[:vc]) do
      new_state = %{state | waiting: :sets.add_element({node(), clock, updates}, state[:waiting])}
      Logger.notice("#{Vectorclock.get(new_state[:vc], :"minidote1@127.0.0.1")}")
      {:noreply, new_state}
    else
      create_effects(updates, state[:objects], [], clock, state[:cb])
      vc = Vectorclock.increment(state[:vc], node())
      result_state = %{state | vc: vc}
      {:reply, {:ok, vc}, result_state}
    end
  end

  def handle_info({:deliver, {p, vc, m}}, state) do
    new_state = update_objects(m, state)
    if p != node()
    do
      new_vc = Vectorclock.increment(new_state[:vc], p)
      {:noreply, %{new_state | vc: new_vc}}
    else
      can_update = Map.get(new_state[:waiting], new_state[:vc])
      if can_update != nil do
        new_state = %{new_state | waiting: Map.delete(new_state[:waiting], new_state[:vc])}
        create_effects(can_update, new_state[:objects], [], new_state[:vc], new_state[:cb])
        vc = Vectorclock.increment(new_state[:vc], node())
        {:noreply, %{new_state | vc: vc}}
      else
        {:noreply, new_state}
      end
    end
  end

  def waiting_update(state, waiting, vc) do
    can_update = :sets.filter(
      fn({_, vcq, _}) -> Vectorclock.leq(vcq, vc) end,
      waiting
    )

    case :sets.size(can_update) do
      0 -> {waiting, vc}
      _ ->
        new_waiting = :sets.subtract(waiting, can_update)
        # state = %{state}
        # new_vc = :sets.fold(fn({p, vcq, u}, vca) -> create_effects)
    end
  end

  def handle_info(msg, state) do
    Logger.warning("Unhandled info message: #{inspect msg}")
    {:noreply, state}
  end

  def read_objects([], _) do
    []
  end

  def read_objects([key | t], objects) do
    obj = Map.get(objects, key)
    if obj == nil do
      [] ++ read_objects(t, objects)
    else
      type = elem(key, 1)
      [{key, :antidote_crdt.value(type, obj)}] ++ read_objects(t, objects)
    end
  end

  def create_effects([], _, effects, clock, cb) do
    GenServer.call(cb, {:rco_broadcast, {node(), clock, effects}})
  end

  def create_effects([{key, effect, value}|t], objects, effects, clock, cb) do
    type = elem(key, 1)
    obj = Map.get(objects, key, :antidote_crdt.new(type))
    {:ok, eff} = :antidote_crdt.downstream(type, {effect, value}, obj)
    {:ok, crdt} = :antidote_crdt.update(type, eff, obj)
    objs = Map.update(objects, key, crdt, fn _ -> crdt end)
    new_effects = effects ++ [{type, eff, obj, key}]
    create_effects(t, objs, new_effects, clock, cb)
  end

  def update_objects([], state) do
    state
  end

  def update_objects([{type, eff, obj, key} | t], state) do
    {:ok, crdt} = :antidote_crdt.update(type, eff, obj)
    objs = Map.update(state[:objects], key, crdt, fn _ -> crdt end)
    new_state = %{state | objects: objs}
    update_objects(t, new_state)
  end
end
