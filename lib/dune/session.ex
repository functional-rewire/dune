defmodule Dune.Session do
  @moduledoc """
  Sessions provide a way to evaluate code and keep state (bindings, modules...) between evaluations.

  - Use `Dune.eval_string/2` to execute code as a one-off
  - Use `Dune.Session.eval_string/3` to execute consecutive code blocks

  `Dune.Session` could be used to implement something like a safe IEx shell, or to compile a module
  once and call it several times without the overhead of parsing.

  `Dune.Session` is also a struct that is used to store the state of an evaluation.

  Only the following fields are public:
  - `last_result`: contains the result of the last evaluation, or `nil` for empty sessions

  Other fields are private and shouldn't be accessed directly.

  """

  alias Dune.{Allowlist, Eval, Parser, Success, Failure, Opts}

  @opaque private_env :: Eval.Env.t()
  @opaque private_compile_env :: Parser.CompileEnv.t()

  @typedoc """
  The type of a `Dune.Session`.
  """
  @type t :: %__MODULE__{
          last_result: nil | Success.t() | Failure.t(),
          env: private_env,
          compile_env: private_compile_env,
          bindings: keyword
        }
  @enforce_keys [:env, :compile_env, :bindings, :last_result]
  defstruct @enforce_keys

  @default_env Eval.Env.new(Dune.AtomMapping.new(), Allowlist.Default)
  @default_compile_env Parser.CompileEnv.new(Allowlist.Default)

  @doc """
  Returns a new empty session.

  ## Examples

      iex> Dune.Session.new()
      #Dune.Session<last_result: nil, ...>

  """
  @spec new :: t
  def new do
    %__MODULE__{
      env: @default_env,
      compile_env: @default_compile_env,
      bindings: [],
      last_result: nil
    }
  end

  @doc """
  Evaluates the provided `string` in the context of the `session` and returns a new session.

  The result will be available in the `last_result` key.
  In case of a success, the variable bindings or created modules will be saved in the session.
  In case of a failure, the rest of the session state won't be updated, so it is possible to
  keep executing instructions after a failure

  ## Examples

      iex> Dune.Session.new()
      ...> |> Dune.Session.eval_string("x = 1")
      ...> |> Dune.Session.eval_string("x + 2")
      #Dune.Session<last_result: %Dune.Success{value: 3, inspected: "3", stdio: ""}, ...>

      iex> Dune.Session.new()
      ...> |> Dune.Session.eval_string("x = 1")
      ...> |> Dune.Session.eval_string("x = x / 0")  # will fail, but the previous state is kept
      ...> |> Dune.Session.eval_string("x + 2")
      #Dune.Session<last_result: %Dune.Success{value: 3, inspected: "3", stdio: ""}, ...>

  """
  @spec eval_string(t, String.t(), keyword) :: t
  def eval_string(session = %__MODULE__{}, string, opts \\ []) do
    opts = Opts.validate!(opts)

    parse_state = %{atom_mapping: session.env.atom_mapping, compile_env: session.compile_env}
    parsed = Parser.parse_string(string, opts, parse_state)

    parsed
    |> Eval.run(opts, session)
    |> add_result_to_session(session, parsed)
  end

  defp add_result_to_session(result = %Success{value: {value, env, bindings}}, session, %{
         compile_env: compile_env
       }) do
    result = %{result | value: value}
    %{session | env: env, compile_env: compile_env, last_result: result, bindings: bindings}
  end

  defp add_result_to_session(result = %Failure{}, session, _) do
    %{session | last_result: result}
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(session, opts) do
      container_doc(
        "#Dune.Session<",
        [last_result: session.last_result],
        ", ...>",
        opts,
        &do_inspect/2,
        break: :strict
      )
    end

    defp do_inspect({key, value}, opts) do
      key = inspect_as_key(key) |> color(:atom, opts)
      concat(key, concat(" ", to_doc(value, opts)))
    end

    if Code.ensure_loaded?(Macro) and function_exported?(Macro, :inspect_atom, 2) do
      defp inspect_as_key(key), do: Macro.inspect_atom(:key, key)
    else
      defp inspect_as_key(key), do: Code.Identifier.inspect_as_key(key)
    end
  end
end
