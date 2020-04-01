defmodule Groot.Register do
  @moduledoc false
  # LWW Register.

  # Creates a new register
  def new(key, val, hlc) do
    %{key: key, value: val, hlc: hlc}
  end

  # Updates the value and creates a new HLC for our register
  def update(register, val, hlc) do
    %{register | value: val, hlc: hlc}
  end

  # Finds the "latest" register by comparing HLCs
  def latest(reg1, reg2) do
    [reg1, reg2]
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1, fn a, b -> !HLClock.before?(a.hlc, b.hlc) end)
    |> Enum.at(0)
  end
end

