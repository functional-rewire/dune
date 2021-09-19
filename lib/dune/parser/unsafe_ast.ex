defmodule Dune.Parser.UnsafeAst do
  @moduledoc false

  @type atom_mapping :: {atom, String.t()}
  @type t :: %__MODULE__{
          ast: String.t(),
          atom_mapping: Dune.AtomMapping.t()
        }
  @enforce_keys [:ast, :atom_mapping]
  defstruct [:ast, :atom_mapping]
end
