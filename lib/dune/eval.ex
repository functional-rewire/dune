defmodule Dune.Eval do
  @moduledoc false

  alias Dune.{AtomMapping, Success, Failure}
  alias Dune.Eval.{Env, Opts}
  alias Dune.Parser.SafeAst
  alias Dune.Shims

  @eval_env [
    requires: [Kernel, Dune.Shims.Kernel],
    macros: [
      {Kernel, Kernel.__info__(:macros)},
      {Dune.Shims.Kernel, [safe_sigil_w: 3, safe_sigil_W: 3]}
    ]
  ]

  @typep previous_session :: %{:bindings => keyword, :env => Env.t(), optional(any) => any}

  @spec run(SafeAst.t() | Failure.t(), Opts.t(), previous_session | nil) ::
          Success.t() | Failure.t()
  def run(parsed, opts, previous_session \\ nil)

  def run(
        %SafeAst{ast: ast, atom_mapping: atom_mapping, compile_env: %{allowlist: allowlist}},
        opts = %Opts{},
        previous_session
      ) do
    case previous_session do
      nil ->
        env = Env.new(atom_mapping, allowlist)
        do_run(ast, atom_mapping, opts, env, nil)

      %{bindings: bindings, env: env} ->
        env = %{env | atom_mapping: atom_mapping, allowlist: allowlist}
        do_run(ast, atom_mapping, opts, env, bindings)
    end
  end

  def run(%Failure{} = failure, _opts, _bindings), do: failure

  defp do_run(ast, atom_mapping, opts, env, bindings) do
    result =
      Dune.Eval.Process.run(
        fn ->
          safe_eval(ast, env, bindings)
        end,
        opts
      )

    AtomMapping.replace_in_result(atom_mapping, result)
  end

  defp safe_eval(safe_ast, env, bindings) do
    try do
      do_safe_eval(safe_ast, env, bindings)
    catch
      failure = %Failure{} ->
        failure
    end
  end

  defp do_safe_eval(safe_ast, env, nil) do
    binding = [env__Dune__: env]
    {value, new_env, _new_bindings} = do_eval_quoted(safe_ast, binding)

    %Success{
      value: value,
      # another important thing about inspect/1 is that it force-evalates
      # potentially huge shared structs => OOM before sending
      inspected: Shims.Kernel.safe_inspect(new_env, value),
      stdio: ""
    }
  end

  defp do_safe_eval(safe_ast, env, bindings) when is_list(bindings) do
    binding = [env__Dune__: env] ++ bindings
    {value, new_env, new_bindings} = do_eval_quoted(safe_ast, binding)

    %Success{
      value: {value, new_env, new_bindings},
      inspected: Shims.Kernel.safe_inspect(new_env, value),
      stdio: ""
    }
  end

  defp do_eval_quoted(safe_ast, binding) do
    {value, bindings} = Code.eval_quoted(safe_ast, binding, @eval_env)

    {new_env, new_bindings} = fix_atom_bug(bindings) |> Keyword.pop!(:env__Dune__)

    {value, new_env, new_bindings}
  end

  # bug when evaluating plain atoms
  # FIXME: remove this when removing support for Elixir 1.12
  # https://github.com/elixir-lang/elixir/commit/8d5c07c1a4c9f770e731aee1a946537cc9d1be5e#diff-4ef990cb3eea7c6f679e231c209b8e72b628b95318756d6620883131ae084b1c
  defp fix_atom_bug([{{:env__Dune__, nil}, env}]), do: [env__Dune__: env]
  defp fix_atom_bug(bindings), do: bindings
end
