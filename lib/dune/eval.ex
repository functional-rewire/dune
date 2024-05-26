defmodule Dune.Eval do
  @moduledoc false

  alias Dune.{AtomMapping, Success, Failure, Opts}
  alias Dune.Eval.Env
  alias Dune.Eval.MacroEnv
  alias Dune.Parser.SafeAst
  alias Dune.Shims

  @typep previous_session :: %{:bindings => keyword, :env => Env.t(), optional(any) => any}

  @spec run(SafeAst.t() | Failure.t(), Opts.t(), previous_session | nil) ::
          Success.t() | Failure.t()
  def run(parsed, opts, previous_session \\ nil)

  def run(
        %SafeAst{
          ast: ast,
          atom_mapping: atom_mapping,
          compile_env: %{allowlist: allowlist},
          stdio: parser_stdio
        },
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
    |> prepend_parser_stdio(parser_stdio)
  end

  def run(%Failure{} = failure, _opts, _bindings), do: failure

  defp do_run(ast, atom_mapping, opts, env, bindings) do
    result =
      Dune.Eval.Process.run(
        fn ->
          safe_eval(ast, env, bindings, opts.pretty)
        end,
        opts
      )

    AtomMapping.replace_in_result(atom_mapping, result)
  end

  defp prepend_parser_stdio(result, ""), do: result

  defp prepend_parser_stdio(result, parser_stdio) do
    Map.update!(result, :stdio, &(parser_stdio <> &1))
  end

  defp safe_eval(safe_ast, env, bindings, pretty) do
    try do
      inspect_opts = [pretty: pretty, custom_options: [sort_maps: true]]
      do_safe_eval(safe_ast, env, bindings, inspect_opts)
    catch
      failure = %Failure{} ->
        failure
    end
  end

  defp do_safe_eval(safe_ast, env, nil, inspect_opts) do
    binding = [env__Dune__: env]
    {value, new_env, _new_bindings} = eval_quoted(safe_ast, binding)

    %Success{
      value: value,
      # another important thing about inspect is that it force-evaluates
      # potentially huge shared structs => OOM before sending
      inspected: Shims.Kernel.safe_inspect(new_env, value, inspect_opts),
      stdio: ""
    }
  end

  defp do_safe_eval(safe_ast, env, bindings, inspect_opts) when is_list(bindings) do
    binding = [env__Dune__: env] ++ bindings
    {value, new_env, new_bindings} = eval_quoted(safe_ast, binding)

    %Success{
      value: {value, new_env, new_bindings},
      inspected: Shims.Kernel.safe_inspect(new_env, value, inspect_opts),
      stdio: ""
    }
  end

  defp eval_quoted(safe_ast, binding) do
    {value, bindings, _env} = Code.eval_quoted_with_env(safe_ast, binding, MacroEnv.make_env())

    {new_env, new_bindings} = Keyword.pop!(bindings, :env__Dune__)

    {value, new_env, new_bindings}
  end
end
