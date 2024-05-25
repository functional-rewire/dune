defmodule Dune.Eval.FakeModule do
  @moduledoc false

  @type function_with_arity :: {atom, non_neg_integer}

  @type t :: %__MODULE__{
          public_funs: %{optional(atom) => %{required(non_neg_integer) => function}}
        }
  @enforce_keys [:public_funs]
  defstruct @enforce_keys

  def get_function(%__MODULE__{public_funs: funs}, fun_name, arity)
      when is_atom(fun_name) and is_integer(arity) do
    case funs do
      %{^fun_name => %{^arity => fun}} -> {:def, fun}
      _ -> nil
    end
  end
end
