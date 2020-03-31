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
      {HLClock, name: :"#{name}.Groot.Clock", node_id: node_id},
      {Groot.ClockSync, [name: name, sync_interval: 3_000, clock: :"#{name}.Groot.Clock"]},
      {Groot.Storage, [name: name]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp gen_node_id do
    8
    |> :crypto.strong_rand_bytes()
    |> :crypto.bytes_to_integer()
  end
end
