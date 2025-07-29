defmodule Dune.Shims.List do
  @moduledoc false

  alias Dune.Shims

  def to_string(_env, list) when is_list(list) do
    do_to_string(list)
  end

  defp do_to_string(list) when is_list(list) do
    if Enum.any?(list, &is_list/1) do
      # eagerly convert lists to binary to prevent OOM on
      # structural sharing bombs
      Enum.map(list, &do_to_string/1)
    else
      list
    end
    |> List.to_string()
  end

  defp do_to_string(elem), do: elem

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
