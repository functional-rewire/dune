defmodule Dune.Shims.Atom do
  @moduledoc false

  alias Dune.AtomMapping

  def to_string(env, atom) when is_atom(atom) do
    AtomMapping.to_string(env.atom_mapping, atom)
  end

  def to_charlist(env, atom) when is_atom(atom) do
    __MODULE__.to_string(env, atom) |> String.to_charlist()
  end
end
