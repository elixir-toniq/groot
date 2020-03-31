defmodule Groot.ClockSync do
  @moduledoc false
  # This module regularly sends our local HLC to a random node in our cluster.
  # Each node in the cluster does this periodically in order to passively
  # keep HLCs in close proximity to each other. This synchronization is naive
  # but it works fine for small cluster sizes. On large clusters it would be
  # better to use views similar to HyParView ensure messages converge efficiently.

  use GenServer

  alias __MODULE__

  def start_link(args) do
    name = Keyword.fetch!(args, :name)
    GenServer.start_link(__MODULE__, args, name: server_name(name))
  end

  def sync_remote_clock(server, hlc) do
    GenServer.cast(server, {:sync_remote_clock, hlc})
  end

  def init(args) do
    data = %{
      name: Keyword.fetch!(args, :name),
      sync_interval: Keyword.fetch!(args, :sync_interval),
      clock: Keyword.fetch!(args, :clock),
    }

    schedule_sync(data)

    {:ok, data}
  end

  def handle_cast({:sync_remote_clock, hlc}, data) do
    HLClock.recv_timestamp(data.clock, hlc)
    {:noreply, data}
  end

  def handle_info(:sync, data) do
    case Node.list() do
      [] ->
        schedule_sync(data)
        {:noreply, data}

      nodes ->
        node = Enum.random(nodes)
        {:ok, hlc} = HLClock.send_timestamp(data.clock)
        sync_remote_clock({server_name(data.name), node}, hlc)
        schedule_sync(data)
        {:noreply, data}
    end
  end

  def handle_info(_msg, data) do
    {:noreply, data}
  end

  defp schedule_sync(%{sync_interval: interval}) do
    Process.send_after(self(), :sync, interval)
  end

  defp server_name(name) do
    :"#{name}.#{__MODULE__}"
  end
end
