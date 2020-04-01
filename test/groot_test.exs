defmodule GrootTest do
  use ExUnit.Case
  doctest Groot

  setup_all do
    nodes = LocalCluster.start_nodes("groot", 2)

    Groot.start_link(name: TestGroot)

    for node <- nodes do
      :rpc.block_call(node, Groot, :start_link, [[name: TestGroot]])
    end

    {:ok, nodes: nodes}
  end

  setup do
    Groot.delete_all(TestGroot)

    :ok
  end

  test "registers are replicated to connected nodes", %{nodes: nodes} do
    [n1, n2] = nodes

    Groot.set(TestGroot, :key, "value")

    eventually(fn ->
      assert Groot.get(TestGroot, :key) == "value"
      assert :rpc.call(n1, Groot, :get, [TestGroot, :key]) == "value"
      assert :rpc.call(n2, Groot, :get, [TestGroot, :key]) == "value"
    end)
  end

  test "disconnected nodes are caught up when they reconnect", %{nodes: nodes} do
    [n1, n2] = nodes

    Schism.partition([n1])

    :rpc.call(n2, Groot, :set, [TestGroot, :key, "value"])

    eventually(fn ->
      assert Groot.get(TestGroot, :key) == "value"
      assert :rpc.call(n1, Groot, :get, [TestGroot, :key]) == nil
      assert :rpc.call(n2, Groot, :get, [TestGroot, :key]) == "value"
    end)

    Schism.heal([n1, n2])

    eventually(fn ->
      assert Groot.get(TestGroot, :key) == "value"
      assert :rpc.call(n1, Groot, :get, [TestGroot, :key]) == "value"
      assert :rpc.call(n2, Groot, :get, [TestGroot, :key]) == "value"
    end)
  end

  test "sending a register from the past is discarded", %{nodes: nodes} do
    [n1, n2] = nodes

    Schism.partition([n1])

    :rpc.call(n2, Groot, :set, [TestGroot, :key, "first"])

    eventually(fn ->
      assert Groot.get(TestGroot, :key) == "first"
      assert :rpc.call(n1, Groot, :get, [TestGroot, :key]) == nil
      assert :rpc.call(n2, Groot, :get, [TestGroot, :key]) == "first"
    end)

    :rpc.call(n1, Groot, :set, [TestGroot, :key, "second"])

    eventually(fn ->
      assert Groot.get(TestGroot, :key) == "second"
      assert :rpc.call(n1, Groot, :get, [TestGroot, :key]) == "second"
      assert :rpc.call(n2, Groot, :get, [TestGroot, :key]) == "first"
    end)

    Schism.heal([n1, n2])

    eventually(fn ->
      assert Groot.get(TestGroot, :key) == "second"
      assert :rpc.call(n1, Groot, :get, [TestGroot, :key]) == "second"
      assert :rpc.call(n2, Groot, :get, [TestGroot, :key]) == "second"
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

