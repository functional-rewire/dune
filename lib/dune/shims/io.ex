defmodule Dune.Shims.IO do
  @moduledoc false

  alias Dune.{Failure, Shims}

  def puts(env, device \\ :stdio, item)

  def puts(env, :stdio, item) do
    env
    |> Shims.Kernel.safe_to_string(item)
    |> then(&IO.puts(:stdio, &1))
  end

  def puts(_env, _device, _item) do
    error = Failure.restricted_function(IO, :puts, 2)
    throw(error)
  end

  def inspect(env, item, opts \\ []) do
    inspect(env, :stdio, item, opts)
  end

  def inspect(env, :stdio, item, opts) when is_list(opts) do
    inspected = Shims.Kernel.safe_inspect(env, item, opts)

    chardata =
      if label_opt = opts[:label] do
        [Shims.Kernel.safe_to_string(env, label_opt), ": ", inspected]
      else
        inspected
      end

    IO.puts(:stdio, chardata)

    item
  end

  def inspect(_env, _device, _item, opts) when is_list(opts) do
    error = Failure.restricted_function(IO, :inspect, 3)
    throw(error)
  end
end
