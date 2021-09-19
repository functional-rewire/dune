defmodule Dune.Shims.List do
  @moduledoc false

  alias Dune.Shims

  # note: this is probably not safe so not actually used

  def to_existing_atom(env, list) when is_list(list) do
    string = to_string(list)
    # make sure it was actually a flat charlist and not an IO-list
    case to_charlist(string) do
      ^list -> Shims.String.to_existing_atom(env, string)
      _ -> List.to_existing_atom(list)
    end
  end

  def to_existing_atom(_env, list) do
    List.to_existing_atom(list)
  end
end
