defmodule Dune.Parser.UnsafeAst do
  @moduledoc false

  @type t :: %__MODULE__{
          ast: Macro.t(),
          atom_mapping: Dune.AtomMapping.t(),
          stdio: binary()
        }
  @enforce_keys [:ast, :atom_mapping]
  defstruct @enforce_keys ++ [stdio: <<>>]
end
