defmodule Dune.Eval.Env do
  @moduledoc false

  alias Dune.AtomMapping
  alias Dune.Eval.FakeModule

  @type t :: %__MODULE__{
          atom_mapping: AtomMapping.t(),
          allowlist: module,
          fake_modules: %{optional(atom) => FakeModule.t()}
        }
  @enforce_keys [:atom_mapping, :allowlist, :fake_modules]
  defstruct @enforce_keys

  def new(atom_mapping = %AtomMapping{}, allowlist) when is_atom(allowlist) do
    %__MODULE__{atom_mapping: atom_mapping, allowlist: allowlist, fake_modules: %{}}
  end

  def add_module(env = %__MODULE__{fake_modules: modules}, module_name, module = %FakeModule{})
      when is_atom(module_name) do
    # TODO check a bunch of things here:
    # - warn if module redefined
    # - fail if overriding existing module
    # - fail if overriding Kernel/Special forms
    %{env | fake_modules: Map.put(modules, module_name, module)}
  end

  def apply_fake(env = %__MODULE__{}, module, fun_name, args)
      when is_atom(module) and is_atom(fun_name) and is_list(args) do
    arity = length(args)

    case fetch_fake_function(env, module, fun_name, arity) do
      {:def, fun} -> fun.(env, args)
      other -> throw({other, module, fun_name, arity})
    end
  end

  defp fetch_fake_function(%{fake_modules: modules}, module, fun_name, arity) do
    case modules do
      %{^module => fake_module} ->
        case FakeModule.get_function(fake_module, fun_name, arity) do
          nil -> :undefined_function
          {:def, fun} -> {:def, fun}
        end

      _ ->
        :undefined_module
    end
  end
end
