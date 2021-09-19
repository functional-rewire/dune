defmodule Dune.Shims.String do
  @moduledoc false

  alias Dune.AtomMapping

  # note: this is probably not safe so not actually used

  def to_existing_atom(env, string) when is_binary(string) do
    AtomMapping.to_existing_atom(env, string)
  end

  def to_existing_atom(_env, string) do
    String.to_existing_atom(string)
  end
end
