defmodule Dune.Parser.CompileEnv do
  @moduledoc false

  @type name_arity :: {atom, non_neg_integer}
  @type maybe_fake_module :: {:real | :fake, module}
  @type t :: %__MODULE__{
          module: module | nil,
          allowlist: module,
          fake_modules: %{optional(module) => %{optional(name_arity) => :def | :defp}}
          # aliases
          # struct info
          # requires
        }
  @enforce_keys [:module, :allowlist, :fake_modules]
  defstruct @enforce_keys

  def new(allowlist) do
    %__MODULE__{
      allowlist: allowlist,
      module: nil,
      fake_modules: %{}
    }
  end

  def define_fake_module(env = %__MODULE__{fake_modules: fake_modules}, module, name_arities)
      when is_atom(module) and is_map(name_arities) do
    if module_already_exists?(module, fake_modules) do
      throw({:module_conflict, module})
    end

    new_modules = Map.put(fake_modules, module, name_arities)

    %{env | fake_modules: new_modules}
  end

  defp module_already_exists?(module, fake_modules) do
    case fake_modules do
      %{^module => _conflict} -> true
      _ -> Code.ensure_loaded?(module)
    end
  end

  def resolve_mfa(%__MODULE__{}, module, fun_name, arity)
      when module in [Kernel, nil] and fun_name in [:def, :defp] and arity in [1, 2] do
    :outside_module
  end

  def resolve_mfa(env = %__MODULE__{}, module, fun_name, arity)
      when is_atom(module) and is_atom(fun_name) and is_integer(arity) do
    actual_module = resolve_module(module, fun_name, arity)

    case env.allowlist.fun_status(actual_module, fun_name, arity) do
      :undefined_module ->
        resolve_fake_module(env, module, fun_name, arity)

      :undefined_function ->
        case module do
          nil -> resolve_fake_module(env, nil, fun_name, arity)
          _ -> :undefined_function
        end

      :restricted ->
        {:restricted, actual_module}

      other ->
        other
    end
  end

  defp resolve_module(nil, fun_name, arity) do
    if Macro.special_form?(fun_name, arity) do
      Kernel.SpecialForms
    else
      Kernel
    end
  end

  defp resolve_module(module, _fun_name, _arity), do: module

  defp resolve_fake_module(%{module: nil}, nil, _fun_name, _arity), do: :undefined_function

  defp resolve_fake_module(env = %{module: module}, nil, fun_name, arity) do
    resolve_fake_module(env, module, fun_name, arity)
  end

  defp resolve_fake_module(env, module, fun_name, arity) do
    # TODO check current module to know if defp OK
    fun_with_arity = {fun_name, arity}

    case env.fake_modules do
      %{^module => %{^fun_with_arity => def_or_defp}} -> check_private(env, module, def_or_defp)
      _ -> :undefined_module
    end
  end

  defp check_private(_env, module, :def), do: {:fake, module}
  defp check_private(%{module: module}, module, :defp), do: {:fake, module}
  defp check_private(_env, _module, _def), do: :undefined_function
end
