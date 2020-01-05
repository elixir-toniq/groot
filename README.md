# Groot

I am Groot.

## Usage

Groot provides a distributed KV store for ephemeral data. It utilizes LWW-register
CRDTs and Hybrid-Logical clocks in order to provide availability and a level
of consistency. For technical information on Groots implementation please
refer to the [docs](https://hexdocs.pm/groot).

## Installation

```elixir
def deps do
  [
    {:groot, "~> 0.1"}
  ]
end
```

## Usage

```elixir
# Changes are propogated to other nodes.
:ok = Groot.set(:key, "value")

# Read existing values. "Gets" are always done from a local ETS table.
"value" = Groot.get(:key)
```

`set` operations will be replicated to all connected nodes. If new nodes join, or if a node
rejoins the cluster after a network partition then the other nodes in the
cluster will replicate all of their known registers to the new node.

## Caveats

Groot relies on distributed erlang. All of the data stored in Groot is
ephemeral and is *not* maintained in between node restarts. New nodes added to
your cluster will be caught up to current state.

Because we're using CRDTs to propogate changes its possible that a change made
on one node will take time to propogate to the other nodes. Its a safe operation
to run the same operation on multiple nodes. When registers are merged groot
chooses the register with the latest HLC.

Groot replicates all registers to all nodes. If you attempt to store thousands
of keys in Groot you'll probably have a bad time.

## Should I use this?

If you need to store and replicate a relatively small amount of ephemeral
values then Groot will be a good solution for you. If you need anything beyond
those features Groot is probably a bad fit.

Here's some examples of good use cases:

* Feature Flags - [rollout](https://github.com/keathley/rollout) is a good example of this.
* Runtime configuration changes
* User session state
* Generic caching

