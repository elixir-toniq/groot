defmodule GrootTest do
  use ExUnit.Case
  doctest Groot

  setup_all do
    Application.ensure_all_started(:groot)
    nodes = LocalCluster.start_nodes("groot", 2)

    {:ok, nodes: nodes}
  end

  setup do
    Groot.Storage.delete_all()

    :ok
  end

  test "registers are replicated to connected nodes", %{nodes: nodes} do
    [n1, n2] = nodes

    Groot.set(:key, "value")

    eventually(fn ->
      assert :rpc.call(n1, Groot, :get, [:key]) == "value"
      assert :rpc.call(n2, Groot, :get, [:key]) == "value"
    end)
  end

  test "disconnected nodes are caught up when they reconnect", %{nodes: nodes} do
    [n1, n2] = nodes

    Schism.partition([n1])

    :rpc.call(n2, Groot, :set, [:key, "value"])

    eventually(fn ->
      assert Groot.get(:key) == "value"
      assert :rpc.call(n1, Groot, :get, [:key]) == nil
      assert :rpc.call(n2, Groot, :get, [:key]) == "value"
    end)

    Schism.heal([n1, n2])

    eventually(fn ->
      assert Groot.get(:key) == "value"
      assert :rpc.call(n1, Groot, :get, [:key]) == "value"
      assert :rpc.call(n2, Groot, :get, [:key]) == "value"
    end)
  end

  test "sending a register from the past is discarded", %{nodes: nodes} do
    [n1, n2] = nodes

    Schism.partition([n1])

    :rpc.call(n2, Groot, :set, [:key, "first"])

    eventually(fn ->
      assert Groot.get(:key) == "first"
      assert :rpc.call(n1, Groot, :get, [:key]) == nil
      assert :rpc.call(n2, Groot, :get, [:key]) == "first"
    end)

    :rpc.call(n1, Groot, :set, [:key, "second"])

    eventually(fn ->
      assert Groot.get(:key) == "second"
      assert :rpc.call(n1, Groot, :get, [:key]) == "second"
      assert :rpc.call(n2, Groot, :get, [:key]) == "first"
    end)

    Schism.heal([n1, n2])

    eventually(fn ->
      assert Groot.get(:key) == "second"
      assert :rpc.call(n1, Groot, :get, [:key]) == "second"
      assert :rpc.call(n2, Groot, :get, [:key]) == "second"
    end)
  end

  @tag :skip
  test "crashing processes does not result in lost data" do
    flunk "Not Implemented"
  end

  def eventually(f, retries \\ 0) do
    f.()
  rescue
    err ->
      if retries >= 10 do
        reraise err, __STACKTRACE__
      else
        :timer.sleep(500)
        eventually(f, retries + 1)
      end
  catch
    _exit, _term ->
      :timer.sleep(500)
      eventually(f, retries + 1)
  end
end

