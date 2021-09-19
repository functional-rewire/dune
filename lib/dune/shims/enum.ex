defmodule Dune.Shims.Enum do
  @moduledoc false

  def join(env, enumerable, joiner \\ "") when is_binary(joiner) do
    enumerable
    |> Enum.map_intersperse(joiner, &Dune.Shims.Kernel.safe_to_string(env, &1))
    |> IO.iodata_to_binary()
  end

  def map_join(env, enumerable, joiner \\ "", mapper)
      when is_binary(joiner) and is_function(mapper, 1) do
    enumerable
    |> Enum.map_intersperse(joiner, &Dune.Shims.Kernel.safe_to_string(env, mapper.(&1)))
    |> IO.iodata_to_binary()
  end
end
