defmodule Dune.Eval.FunctionClauseError do
  @moduledoc false

  defexception [:module, :function, :args]

  def message(err = %__MODULE__{function: function, args: args}) do
    module = inspect(err.module)
    arity = length(args)
    args = inspect(args) |> String.slice(1..-2)

    "no function clause matching in #{module}.#{function}/#{arity}: #{module}.#{function}(#{args})"
  end
end
