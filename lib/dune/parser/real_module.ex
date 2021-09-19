defmodule Dune.Parser.RealModule do
  @moduledoc false

  @spec elixir_module?(module) :: boolean
  def elixir_module?(module) do
    module
    |> Atom.to_string()
    |> String.starts_with?("Elixir.")
  end

  def list_functions(module)

  def list_functions(Kernel.SpecialForms) do
    [{:%{}, 2}] ++ Kernel.SpecialForms.__info__(:macros)
  end

  @spec list_functions(module) :: [{atom, non_neg_integer}]
  def list_functions(module) when is_atom(module) do
    if elixir_module?(module) do
      module.__info__(:functions) ++ module.__info__(:macros)
    else
      for {f, _a} = fa <- module.module_info(:exports), f != :module_info, do: fa
    end
  end

  def fun_exists?(module, fun_name, arity) do
    # TODO replace with fun_status
    fun_status(module, fun_name, arity) == :defined
  end

  def fun_status(module, fun_name, arity)

  def fun_status(Kernel.SpecialForms, fun_name, arity) do
    if Macro.special_form?(fun_name, arity) do
      :defined
    else
      :undefined_function
    end
  end

  def fun_status(module, fun_name, arity) do
    cond do
      not Code.ensure_loaded?(module) -> :undefined_module
      function_exported?(module, fun_name, arity) -> :defined
      macro_exported?(module, fun_name, arity) -> :defined
      true -> :undefined_function
    end
  end
end
