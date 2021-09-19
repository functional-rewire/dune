defmodule Dune.Allowlist do
  @moduledoc """
  Behaviour to customize the modules and functions that are allowed or restricted.

  ## Warning: security considerations

  The default implementation is `Dune.Allowlist.Default`, and should only allow safe
  functions: no atom leaks, no execution of arbitrary code, no access to the filesystem / network...
  Defining or extending a custom `Dune.Allowlist` module can introduce security risks or bugs.

  Please also note that using custom allowlists is still **experimental** and the API for it
  might change faster than the rest of the library.

  ## Defining a new allowlist

  In order to define a custom allowlist from scratch, `use Dune.Allowlist` can be used:

      defmodule CustomAllowlist do
        use Dune.Allowlist

        allow Kernel, only: [:+, :*, :-, :/, :div, :rem]
      end

      Dune.eval_string("4 + 9", allowlist: CustomAllowlist)

  ## Extending an existing allowlist

  Defining an allowlist from scratch can be both daunting and risky.
  It is possible to extend an exisiting allowlist instead using the `extend` option:

      defmodule ExtendedAllowlist do
        use Dune.Allowlist, extend: Dune.Allowlist.Default

        allow SomeModule, only: [:authorized]
      end

      Dune.eval_string("SomeModule.authorized(123)", allowlist: ExtendedAllowlist)

  Note: currently, it is not possible to add or restrict functions from modules
  that have already been specified.

  ## Documentation generation

  The list of modules and functions with their status can be generated in the `@moduledoc`.
  An example can be found in the  `Dune.Allowlist.Default` documentation.

  If the `__DUNE_ALLOWLIST_FUNCTIONS__` string is found in the `@moduledoc` string,
  it will be replaced.

      defmodule CustomAllowlist do
        @moduledoc \"\"\"
        Only allows simple arithmetic

        ## Allowlist functions

        __DUNE_ALLOWLIST_FUNCTIONS__
        \"\"\"

        use Dune.Allowlist

        allow Kernel, only: [:+, :*, :-, :/, :div, :rem]
      end

  """

  @type status :: :allowed | :restricted | {:shimmed, module, atom}

  @doc """
  Returns the trust status of a function or macro, specified as a `module`, `fun_name` and `arity` (`mfa`):
  - `:allowed` if can be safely use
  - `:restricted` if its usage should be forbidden
  - a `{:shimmed, module, function_name}` if the function call should be replaced with an alternative implementation
  """
  @callback fun_status(module, atom, non_neg_integer) :: Dune.Allowlist.status()

  @doc """
  Validates the fact that a module implements the `Dune.Allowlist` behaviour.

  Raises if not the case.

  ## Examples

      iex> Dune.Allowlist.ensure_implements_behaviour!(DoesNotExists)
      ** (ArgumentError) could not load module DoesNotExists due to reason :nofile

      iex> Dune.Allowlist.ensure_implements_behaviour!(List)
      ** (ArgumentError) List does not implement the Dune.Allowlist behaviour

  """
  @spec ensure_implements_behaviour!(module) :: module
  def ensure_implements_behaviour!(module) when is_atom(module) do
    Code.ensure_compiled!(module)

    implemented? =
      module.module_info(:attributes)
      |> Keyword.get(:behaviour, [])
      |> Enum.member?(Dune.Allowlist)

    unless implemented? do
      raise ArgumentError,
        message: "#{inspect(module)} does not implement the Dune.Allowlist behaviour"
    end

    module
  end

  defmacro __using__(opts) do
    extend = extract_extend_opt(opts, __CALLER__)

    quote do
      import Dune.Allowlist, only: [allow: 2]

      @behaviour Dune.Allowlist

      Module.register_attribute(__MODULE__, :allowlist, accumulate: true)

      Module.put_attribute(__MODULE__, :extend_allowlist, unquote(extend))

      @before_compile Dune.Allowlist
    end
  end

  @doc """
  Adds a new module to the allowlist and specifices which functions to use.

  The module must not be already specified in the allowlist.

  Must be called after `use Dune.Allowlist`.

  ## Examples

      # allow all functions in a module
      allow Time, :all

      # only allow specific functions
      allow Function, only: [:identity]

      # exclude specific functions
      allow Calendar, except: [:put_time_zone_database]

  Note: `only` and `except` will cover all arities if several functions
  share a name.

  """
  defmacro allow(module, status) do
    quote do
      Module.put_attribute(__MODULE__, :allowlist, {unquote(module), unquote(status)})
    end
  end

  defmacro __before_compile__(env) do
    Dune.Allowlist.__postprocess__(env.module)
  end

  defp extract_extend_opt(opts, caller) do
    case Keyword.fetch(opts, :extend) do
      {:ok, module_ast} ->
        Macro.expand(module_ast, caller) |> ensure_implements_behaviour!()

      _ ->
        nil
    end
  end

  @doc false
  def __postprocess__(module) do
    extend = Module.get_attribute(module, :extend_allowlist)
    spec = generate_spec(module, extend)
    update_module_doc(module, spec)

    quote do
      unquote(def_spec(spec))
      unquote(def_fun_status(spec))
    end
  end

  defp generate_spec(module, extend) do
    base_spec =
      case extend do
        nil -> Dune.Allowlist.Spec.new()
        allowlist when is_atom(allowlist) -> allowlist.spec()
      end

    Module.get_attribute(module, :allowlist)
    |> Enum.reduce(base_spec, fn {module, status}, acc ->
      Dune.Allowlist.Spec.add_new_module(acc, module, status)
    end)
  end

  defp def_spec(spec) do
    quote do
      @doc false
      @spec spec :: Dune.Allowlist.Spec.t()
      def spec do
        unquote(Macro.escape(spec))
      end
    end
  end

  defp def_fun_status(spec) do
    defps =
      for {m, f, status} = _ <- Dune.Allowlist.Spec.list_fun_statuses(spec) do
        quote do
          defp do_fun_status(unquote(m), unquote(f)),
            do: unquote(Macro.escape(status))
        end
      end

    quote do
      @impl Dune.Allowlist
      @doc "Implements `c:Dune.Allowlist.fun_status/3`"
      def fun_status(module, fun_name, arity)
          when is_atom(module) and is_atom(fun_name) and is_integer(arity) and arity >= 0 do
        with :defined <- Dune.Parser.RealModule.fun_status(module, fun_name, arity) do
          do_fun_status(module, fun_name)
        end
      end

      unquote(defps)

      defp do_fun_status(_module, _fun_name), do: :restricted
    end
  end

  defp update_module_doc(module, spec) do
    case Module.get_attribute(module, :moduledoc) do
      {line, doc} when is_binary(doc) ->
        doc =
          String.replace(doc, "__DUNE_ALLOWLIST_FUNCTIONS__", fn _ ->
            Dune.Allowlist.Docs.document_allowlist(spec)
          end)

        Module.put_attribute(module, :moduledoc, {line, doc})

      _other ->
        :ok
    end
  end
end
