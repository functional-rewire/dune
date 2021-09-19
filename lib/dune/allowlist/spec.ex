defmodule Dune.Allowlist.Spec do
  @moduledoc false

  alias Dune.Parser.RealModule

  @type status :: Dune.Allowlist.status()

  @type t :: %__MODULE__{modules: %{optional(module) => [{atom, non_neg_integer, status}]}}
  @enforce_keys [:modules]
  defstruct [:modules]

  def new do
    %__MODULE__{modules: %{}}
  end

  @spec list_fun_statuses(t) :: list({module, atom, status})
  def list_fun_statuses(%__MODULE__{modules: modules}) do
    for {module, funs} <- modules, {fun_name, _arity, status} <- funs do
      {module, fun_name, status}
    end
    |> Enum.sort()
    |> Enum.dedup()
  end

  @spec list_ordered_modules(t) :: list({module, {atom, status}})
  def list_ordered_modules(%__MODULE__{modules: modules}) do
    modules
    |> Enum.map(fn {module, funs} ->
      {module, group_funs_by_status(funs)}
    end)
    |> Enum.sort()
  end

  defp group_funs_by_status(funs) do
    Enum.group_by(
      funs,
      fn {_fun, _arity, status} -> extract_status_atom(status) end,
      fn {fun, arity, _status} -> {fun, arity} end
    )
    |> Enum.map(fn {status, funs} -> {status, Enum.sort(funs) |> Enum.dedup_by(&elem(&1, 0))} end)
    |> Enum.sort_by(fn {status, _} -> status_sort(status) end)
  end

  defp extract_status_atom(:restricted), do: :restricted
  defp extract_status_atom(:allowed), do: :allowed
  defp extract_status_atom({:shimmed, _, _}), do: :shimmed

  defp status_sort(:allowed), do: 1
  defp status_sort(:shimmed), do: 2
  defp status_sort(:restricted), do: 3

  @spec add_new_module(t, module, :all) :: t
  def add_new_module(%__MODULE__{modules: modules}, module, _status)
      when :erlang.map_get(module, modules) != nil do
    # TODO proper error type
    raise "ModuleConflict: module #{inspect(module)} already defined"
  end

  def add_new_module(spec = %__MODULE__{modules: modules}, module, status) when is_atom(module) do
    Code.ensure_compiled!(module)

    functions =
      RealModule.list_functions(module)
      |> classify_functions(status)

    %{spec | modules: Map.put(modules, module, functions)}
  end

  defp classify_functions(functions, :all) do
    Enum.map(functions, fn {fun_name, arity} -> {fun_name, arity, :allowed} end)
  end

  defp classify_functions(functions, only: only) when is_list(only) do
    do_classify(functions, only, :allowed, :restricted)
  end

  defp classify_functions(functions, except: except) when is_list(except) do
    do_classify(functions, except, :restricted, :allowed)
  end

  defp classify_functions(functions, opts) do
    case Keyword.pop(opts, :shims) do
      {shims, remaining_opts} when is_list(shims) ->
        new_opts =
          case remaining_opts do
            [] -> :all
            other -> other
          end

        classify_functions(functions, new_opts) |> shim_functions(shims)

      {nil, _} ->
        raise "Invalid opts #{inspect(opts)}"
    end
  end

  defp do_classify(functions, set_list, member_atom, non_member_atom) do
    set = to_atom_set(set_list)

    functions
    |> Enum.map_reduce(set, fn {fun_name, arity}, acc ->
      case set do
        %{^fun_name => _} -> {{fun_name, arity, member_atom}, Map.delete(acc, fun_name)}
        _ -> {{fun_name, arity, non_member_atom}, acc}
      end
    end)
    |> unwrap_classify()
  end

  defp to_atom_set(list) do
    Enum.each(list, fn atom when is_atom(atom) -> :ok end)
    :maps.from_keys(list, nil)
  end

  defp unwrap_classify({result, remaining}) when remaining == %{}, do: result

  defp unwrap_classify({_, remaining}) do
    [{key, _}] = Enum.take(remaining, 1)
    raise "Unknown function #{key}"
  end

  defp shim_functions(functions, shims) do
    # TODO validate shims
    Enum.map(functions, fn fun = {fun_name, arity, _status} ->
      case Keyword.get(shims, fun_name) do
        nil ->
          fun

        {shim_module, shim_fun_name} ->
          validate_shim!(shim_module, shim_fun_name, arity + 1)
          {fun_name, arity, {:shimmed, shim_module, shim_fun_name}}
      end
    end)
  end

  defp validate_shim!(module, fun_name, arity) do
    Code.ensure_compiled!(module)

    unless function_exported?(module, fun_name, arity) or macro_exported?(module, fun_name, arity) do
      raise "Invalid shim: function #{inspect(module)}.#{fun_name}/#{arity} doesn't exist!"
    end
  end
end
