defmodule Dune.Helpers.TermChecker do
  @moduledoc false

  defguardp is_simple_term(term)
            when is_atom(term) or is_bitstring(term) or is_number(term) or is_reference(term) or
                   is_function(term) or is_pid(term) or is_port(term) or term == []

  @doc """
  Walks the term recursively to make sure it is not a humongous tree built using structural sharing
  """
  def check(term), do: do_check(term)

  defp do_check(term) when is_simple_term(term), do: :ok

  defp do_check([left | right]) when is_simple_term(left) do
    do_check(right)
  end

  defp do_check([left | right]) do
    do_check(left)
    do_check(right)
  end

  defp do_check(map) when is_map(map) do
    Map.to_list(map) |> do_check()
  end

  defp do_check(tuple) when is_tuple(tuple) do
    Tuple.to_list(tuple) |> do_check()
  end
end
