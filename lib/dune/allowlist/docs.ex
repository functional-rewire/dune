defmodule Dune.Allowlist.Docs do
  @moduledoc false

  def document_allowlist(spec) do
    spec
    |> Dune.Allowlist.Spec.list_ordered_modules()
    |> Enum.map_join("\n", &do_doc_funs/1)
  end

  def public_functions(module) when is_atom(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, _, _, list} ->
        for {{:function, function_name, _}, _, _, %{}, %{}} <- list, into: MapSet.new() do
          function_name
        end

      _ ->
        []
    end
  end

  defp do_doc_funs({module, grouped_funs}) do
    public_funs = public_functions(module)

    head = ["- `", inspect(module), "`"]

    tail =
      Enum.map(grouped_funs, fn {status, funs} ->
        [
          "**",
          format_status(status),
          "**: " | Enum.map_intersperse(funs, ", ", &format_fun(module, &1, status, public_funs))
        ]
      end)

    Enum.intersperse([head | tail], "\n  - ") |> to_string()
  end

  defp format_fun(module, {fun, arity}, status, public_funs) do
    if fun in public_funs or module in [Kernel, Kernel.SpecialForms] do
      [
        ?[,
        maybe_strike(status),
        ?`,
        Atom.to_string(fun),
        ?`,
        maybe_strike(status),
        "](`",
        inspect(module),
        ?.,
        to_string(fun),
        ?/,
        to_string(arity),
        "`)"
      ]
    else
      [
        maybe_strike(status),
        ?`,
        Atom.to_string(fun),
        ?`,
        maybe_strike(status)
      ]
    end
  end

  defp maybe_strike(:restricted), do: "~~"
  defp maybe_strike(_status), do: []

  defp format_status(:allowed), do: "Allowed"
  defp format_status(:shimmed), do: "Alernative implementation"
  defp format_status(:restricted), do: "Restricted"
end

Dune.Allowlist.Docs.public_functions(:rand)
