defmodule Groot.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(opts) do
    name = opts[:name] || raise ArgumentError, "Groot requires a `:name` option"
    Supervisor.start_link(__MODULE__, opts)
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
      {Groot.Storage, [name: storage_name(name)]}
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
