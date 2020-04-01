defmodule Groot.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # node_id = gen_node_id()

    children = [
      # {HLClock, name: Groot.Clock, node_id: node_id},
      # {Groot.ClockSync, [sync_interval: 3_000, clock: Groot.Clock]},
      # {Groot.Storage, []}
    ]

    opts = [strategy: :one_for_one, name: Groot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp gen_node_id do
    8
    |> :crypto.strong_rand_bytes()
    |> :crypto.bytes_to_integer()
  end
end
