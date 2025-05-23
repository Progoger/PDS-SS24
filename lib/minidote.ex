defmodule Minidote do
  @moduledoc """
  The API documentation for `Minidote`.
  """

  require Logger

  @type key :: {binary(), :antidote_crdt.typ(), binary()}
  @type clock :: Vectorclock # your clock type here

  @spec read_objects([key()], clock()) :: {:ok, [{key(), :antidote_crdt.value()}], clock()} | {:error, any()}
  def read_objects(objects, clock) do
      Logger.notice("#{node()}: read_objects(#{inspect objects}, #{inspect clock})")
      GenServer.call(Minidote.Server, {:read_objects, objects, clock})
  end

  @spec update_objects([{key(), atom(), any()}], clock()) :: {:ok, clock()} | {:error, any()}
  def update_objects(updates, clock) do
      Logger.notice("#{node()}: update_objects(#{inspect updates}, #{inspect clock})")
      GenServer.call(Minidote.Server, {:update_objects, updates, clock})
  end

end
