defmodule Groot do
  @moduledoc """
  Groot provides an eventually consistent, ephemeral KV store. It relies on
  distributed erlang and uses LWW-registers and Hybrid-logical clocks
  to ensure maximum availability. Groot utilizes ETS for efficient reading.

  ## Usage

  ```elixir
  # Changes are propogated to other nodes.
  :ok = Groot.set(:key, "value")

  # Read existing values
  "value" = Groot.get(:key)
  ```

  Updates will replicate to all connected nodes. If a new node joins, or if a node
  rejoins the cluster after a network partition then the other nodes in the
  cluster will replicate all of their registers to the new node.

  ## Consistency

  Groot uses LWW register CRDTs for storing values. Each register includes a
  hybrid logical clock (HLC). Ordering of events is determined by comparing HLCs.
  If a network partition occurs nodes on either side of the partition will
  continue to accept `set` and `get` operations. Once the partition heals, all
  registers will be replicated to all nodes. If there are any conflicts, the
  register with the largest HLC will be chosen.

  Groot may lose writes under specific failures scenarios. For instance, if
  there is a network partition between 2 nodes, neither node will be able to
  replicate to the other. If either node crashes after accepting a write, that
  write will be lost.

  ## Data limitations

  Groot replicates all keys to all connected nodes. Thus there may be performance
  issues if you attempt to store hundreds or thousands of keys. This issue may
  be fixed in a future release.
  """
  use Supervisor

  alias Groot.Storage

  @doc """
  Gets a register's value. If the register is not found it returns `nil`.
  """
  def get(server, key) do
    Storage.get(storage_name(server), key)
  end

  @doc """
  Sets the value for a register.
  """
  def set(server, key, value) do
    Storage.set(storage_name(server), key, value)
  end

  @doc false
  # This is only here for development and testing purposes. You probably
  # don't want to use this in production.
  def delete_all(server) do
    Storage.delete_all(storage_name(server))
  end

  def start_link(opts) do
    name = opts[:name] || raise ArgumentError, "Groot requires a `:name` option"
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    name = opts[:name]
    node_id = gen_node_id()

    children = [
      {HLClock, name: clock_name(name), node_id: node_id},
      {Groot.ClockSync, [
        name: clock_sync_name(name),
        sync_interval: 3_000,
        clock: clock_name(name),
      ]},
      {Groot.Storage, [name: storage_name(name), clock: clock_name(name)]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp clock_name(name), do: :"#{name}.Groot.Clock"
  defp clock_sync_name(name), do: :"#{name}.Groot.ClockSync"
  defp storage_name(name), do: :"#{name}.Groot.Storage"

  defp gen_node_id do
    8
    |> :crypto.strong_rand_bytes()
    |> :crypto.bytes_to_integer()
  end
end

