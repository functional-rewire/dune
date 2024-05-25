defmodule Dune.Parser.SafeAst do
  @moduledoc false

  @type t :: %__MODULE__{
          ast: String.t(),
          atom_mapping: Dune.AtomMapping.t(),
          compile_env: Dune.Parser.CompileEnv.t()
        }
  @enforce_keys [:ast, :atom_mapping, :compile_env]
  defstruct @enforce_keys
end
