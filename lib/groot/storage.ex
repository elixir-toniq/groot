defmodule Groot.Storage do
  @moduledoc false
  # This module provides a genserver for maintaining registers. It monitors
  # node connects in order to propagate existing registers.
  # TODO: This genserver is a bottleneck on the system. We should really try
  # to resolve this and move more work into the calling process in the future.

  use GenServer

  alias Groot.Register

  def start_link(args) do
    args = Keyword.fetch!(args, :name)
    GenServer.start_link(__MODULE__, args, name: server_name(name))
  end

  # Lookup the value for the key in ets. Return nil otherwise
  def get(server, key) do
    case :ets.lookup(server_name(server), key) do
      [] ->
        nil

      [{^key, value}] ->
        value
    end
  end

  # The main api for setting a keys value
  def set(server, key, value) do
    GenServer.call(server, {:set, key, value})
  end

  # Deletes all keys in the currently connected cluster. This is only
  # intended to be used in development and test
  def delete_all(server) do
    GenServer.multi_call(server, :delete_all)
  end

  def init(args) do
    name = Keyword.fetch!(args, :name)
    :net_kernel.monitor_nodes(true)
    ^name = __MODULE__ = :ets.new(name, [:named_table, :set, :protected])
    registers = %{}
    schedule_sync_timeout()

    {:ok, %{name: name, registers: registers}}
  end

  def handle_call({:set, key, value}, _from, data) do
    registers = Map.update(data.registers, key, Register.new(key, value), fn reg ->
      Register.update(reg, value)
    end)
    :ets.insert(data.name, {key, registers[key].value})
    GenServer.abcast(data.name, {:update_register, registers[key]})

    {:reply, :ok, %{data | registers: registers}}
  end

  def handle_call(:delete_all, _from, data) do
    registers = %{}
    :ets.delete_all_objects(data.name)

    {:reply, :ok, %{data | registers: registers}}
  end

  def handle_cast({:update_register, reg}, data) do
    registers = Map.update(data.registers, reg.key, reg, fn existing_reg ->
      Register.latest(reg, existing_reg)
    end)
    :ets.insert(data.name, {reg.key, registers[reg.key].value})
    {:noreply, %{data | registers: registers}}
  end

  def handle_cast({:update_registers, registers}, data) do
    new_registers = merge(data.registers, registers)

    for {key, reg} <- new_registers do
      :ets.insert(data.name, {key, reg.value})
    end

    {:noreply, %{data | registers: new_registers}}
  end

  def handle_info(msg, data) do
    case msg do
      {:nodeup, node} ->
        GenServer.cast({data.name, node}, {:update_registers, data.registers})
        {:noreply, data}

      :sync_timeout ->
        GenServer.abcast(data.name, {:update_registers, data.registers})
        schedule_sync_timeout()
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

  defp server_name(name) do
    :"#{name}.#{__MODULE__}"
  end
end
