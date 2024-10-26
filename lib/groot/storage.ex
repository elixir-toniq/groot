defmodule Groot.Storage do
  @moduledoc false
  # This module provides a genserver for maintaining registers. It monitors
  # node connects in order to propagate existing registers.
  # TODO: This genserver is a bottleneck on the system. We should really try
  # to resolve this and move more work into the calling process in the future.

  use GenServer

  alias Groot.Register

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  # Lookup the value for the key in ets. Return nil otherwise
  def get(key) do
    case :ets.lookup(__MODULE__, key) do
      [] ->
        nil

      [{^key, value}] ->
        value
    end
  end

  # The main api for setting a keys value
  def set(key, value, expires_in \\ nil) do
    GenServer.call(__MODULE__, {:set, key, value, expires_in})
  end

  # The main api for deleting a key
  def delete(key) do
    case :ets.lookup(__MODULE__, key) do
      [] ->
        :ok

      [{^key, _value}] ->
        GenServer.call(__MODULE__, {:delete, key})
    end
  end

  # Deletes all keys in the currently connected cluster. This is only
  # intended to be used in development and test
  def delete_all() do
    GenServer.multi_call(__MODULE__, :delete_all)
  end

  def init(_args) do
    :net_kernel.monitor_nodes(true)
    tab = __MODULE__ = :ets.new(__MODULE__, [:named_table, :set, :protected])
    registers = %{}
    schedule_sync_timeout()

    {:ok, %{table: tab, registers: registers}}
  end

  def handle_call({:set, key, value, expires_in}, _from, data) do
    registers = Map.update(data.registers, key, Register.new(key, value), fn reg ->
      Register.update(reg, value)
    end)
    :ets.insert(data.table, {key, registers[key].value})
    GenServer.abcast(__MODULE__, {:update_register, registers[key]})

    case expires_in do
       nil -> :ok
       _ -> Process.send_after(self(), {:delete, key}, expires_in)
    end

    {:reply, :ok, %{data | registers: registers}}
  end

  def handle_call({:delete, key}, _from, data) do
    registers = Map.delete(data.registers, key)
    :ets.delete(data.table, key)
    GenServer.abcast(__MODULE__, {:propagate_delete, key})

    {:reply, :ok, %{data | registers: registers}}
  end

  def handle_call(:delete_all, _from, data) do
    registers = %{}
    :ets.delete_all_objects(data.table)

    {:reply, :ok, %{data | registers: registers}}
  end

  def handle_cast({:update_register, reg}, data) do
    registers = Map.update(data.registers, reg.key, reg, fn existing_reg ->
      Register.latest(reg, existing_reg)
    end)
    :ets.insert(data.table, {reg.key, registers[reg.key].value})
    {:noreply, %{data | registers: registers}}
  end

  def handle_cast({:update_registers, registers}, data) do
    new_registers = merge(data.registers, registers)

    for {key, reg} <- new_registers do
      :ets.insert(data.table, {key, reg.value})
    end

    {:noreply, %{data | registers: new_registers}}
  end

  def handle_cast({:propagate_delete, key}, data) do
    registers = Map.delete(data.registers, key)
    :ets.delete(data.table, key)
    {:noreply, %{data | registers: registers}}
  end

  def handle_info(msg, data) do
    case msg do
      {:nodeup, node} ->
        GenServer.cast({__MODULE__, node}, {:update_registers, data.registers})
        {:noreply, data}

      :sync_timeout ->
        GenServer.abcast(__MODULE__, {:update_registers, data.registers})
        schedule_sync_timeout()
        {:noreply, data}

      :delete ->
        GenServer.call(__MODULE__, {:delete, data})
        {:noreply, data}

      _msg ->
        {:noreply, data}
    end
  end

  defp schedule_sync_timeout do
    # Wait between 10 and 20 seconds before doing another sync
    next_timeout = (:rand.uniform(10) * 1000) + 10_000
    Process.send_after(self(), :sync_timeout, next_timeout)
  end

  defp merge(r1, r2) do
    keys =
      [Map.keys(r1), Map.keys(r2)]
      |> List.flatten()
      |> Enum.uniq

    keys
    |> Enum.map(fn key -> {key, Register.latest(r1[key], r2[key])} end)
    |> Enum.into(%{})
  end
end
