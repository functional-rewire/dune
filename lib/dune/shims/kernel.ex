defmodule Dune.Shims.Kernel do
  @moduledoc false

  alias Dune.{AtomMapping, Failure, Shims}

  defmacro safe_sigil_w(_env, _, ~c"a") do
    error = Failure.restricted_function(Kernel, :sigil_w, 2)
    throw(error)
  end

  defmacro safe_sigil_w(_env, term, modifiers) do
    quote do
      sigil_w(unquote(term), unquote(modifiers))
    end
  end

  defmacro safe_sigil_W(_env, _, ~c"a") do
    error = Failure.restricted_function(Kernel, :sigil_W, 2)
    throw(error)
  end

  defmacro safe_sigil_W(_env, term, modifiers) do
    quote do
      sigil_W(unquote(term), unquote(modifiers))
    end
  end

  defmacro safe_dbg(_env) do
    error = Failure.restricted_function(Kernel, :safe_dbg, 0)
    throw(error)
  end

  defmacro safe_dbg(_env, _term) do
    # should never be called because the sanitizer handles it
    raise "unexpected call safe_dbg/2"
  end

  defmacro safe_dbg(_env, _term, _opts) do
    error = Failure.restricted_function(Kernel, :safe_dbg, 2)
    throw(error)
  end

  def safe_dot(_env, %{} = map, key) do
    # TODO test key error
    Map.fetch!(map, key)
  end

  def safe_dot(env, module, fun) when is_atom(module) do
    safe_apply(env, module, fun, [])
  end

  def safe_apply(_env, fun, args) when is_function(fun, 1) do
    # TODO check if there is a risk / why it is here
    apply(fun, args)
  end

  def safe_apply(env, module, fun, args) when is_atom(module) do
    arity = length(args)

    case env.allowlist.fun_status(module, fun, arity) do
      :restricted ->
        error = Failure.restricted_function(module, fun, arity)
        throw(error)

      {:shimmed, shim_module, shim_fun} ->
        apply(shim_module, shim_fun, [env | args])

      :allowed ->
        apply(module, fun, args)

      :undefined_module ->
        Dune.Eval.Env.apply_fake(env, module, fun, args)

      :undefined_function ->
        throw({:undefined_function, module, fun, arity})

      other when other in [:undefined_module, :undefined_function] ->
        Dune.Eval.Env.apply_fake(env, module, fun, args)
    end
  end

  def safe_inspect(env, term, opts \\ [])

  def safe_inspect(_env, term, opts)
      when is_number(term) or is_binary(term) or is_boolean(term) do
    inspect(term, opts)
  end

  def safe_inspect(env, atom, _opts) when is_atom(atom) do
    AtomMapping.inspect(env.atom_mapping, atom)
  end

  def safe_inspect(env, term, opts) do
    inspected = inspect(term, opts)
    AtomMapping.replace_in_string(env.atom_mapping, inspected)
  end

  def safe_to_string(env, atom) when is_atom(atom) do
    Shims.Atom.to_string(env, atom)
  end

  def safe_to_string(_env, other), do: to_string(other)

  def safe_to_charlist(env, atom) when is_atom(atom) do
    Shims.Atom.to_charlist(env, atom)
  end

  def safe_to_charlist(_env, other), do: to_charlist(other)
end
