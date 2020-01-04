defmodule Groot do
  @moduledoc """
  Groot allows you to flip features quickly and easily. It relies on
  distributed erlang and uses LWW-register and Hybrid-logical clocks
  to provide maximum availability. Rollout has no dependency on an external
  service such as redis which means rollout feature flags can be used in the
  critical path of a request with minimal latency increase.

  ## Usage

  Rollout provides a simple api for enabling and disabling feature flags across
  your cluster. A feature flag can be any term.

  ```elixir
  # Check if a feature is active
  Rollout.active?(:blog_post_comments)
  # => false

  # Activate the feature
  Rollout.activate(:blog_post_comments)

  # De-activate the feature
  Rollout.deactivate(:blog_post_comments)
  ```

  You can also activate a feature a certain percentage of the time.

  ```elixir
  Rollout.activate_percentage(:blog_post_comments, 20)
  ```

  You can run this function on one node in your cluster and the updates will
  be propogated across the system. This means that updates to feature flags may
  not be instantaneous across the cluster but under normal conditions should propogate
  quickly. This is a tradeoff I've made in order to maintain the low latency when
  checking if a flag is enabled.

  ## How does Rollout work?

  Rollout maintains a LWW Register for each flag that has been activated or
  deactivated. These Registers use hybrid logical clocks (HLC) for causality
  tracking. When a flag is activated or deactivated we update the HLC for that
  register and propogate the register across the cluster. When merging registers
  we always take register with the latest HLC. After merging is
  done we store the values for each register into an ets table for fast lookups.
  """

  alias Groot.Storage

  @doc """
  Gets a register's value. If the register is not found it returns `nil`.
  """
  def get(key) do
    Storage.get(key)
  end

  @doc """
  Sets the value for a register.
  """
  def set(key, value) do
    Storage.set(key, value)
  end
end

