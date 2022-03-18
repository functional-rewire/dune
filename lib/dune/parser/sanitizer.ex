defmodule Dune.Parser.Sanitizer do
  @moduledoc false

  alias Dune.{Failure, AtomMapping}
  alias Dune.Parser.{CompileEnv, RealModule, UnsafeAst, SafeAst, Opts}

  @env_variable_name :env__Dune__

  @spec sanitize(UnsafeAst.t() | Failure.t(), Opts.t()) :: SafeAst.t() | Failure.t()
  def sanitize(unsafe = %UnsafeAst{}, compile_env = %CompileEnv{}) do
    case try_sanitize(unsafe.ast, compile_env) do
      {:ok, safe_ast, new_env} ->
        %SafeAst{
          ast: safe_ast,
          atom_mapping: unsafe.atom_mapping,
          compile_env: new_env
        }

      {:restricted, module, fun, arity} ->
        failure = Failure.restricted_function(module, fun, arity)
        AtomMapping.replace_in_result(unsafe.atom_mapping, failure)

      {:undefined_module, module, func_name, arity} ->
        failure = Failure.undefined_module(module, func_name, arity)
        AtomMapping.replace_in_result(unsafe.atom_mapping, failure)

      {:undefined_function, module, func_name, arity} ->
        failure = Failure.undefined_function(module, func_name, arity)
        AtomMapping.replace_in_result(unsafe.atom_mapping, failure)

      {:module_restricted, ast} ->
        message =
          "** (DuneRestrictedError) the following syntax is restricted inside defmodule:\n         #{Macro.to_string(ast)}"

        new_failure(:module_restricted, message, unsafe.atom_mapping)

      {:module_conflict, module} ->
        message =
          "** (DuneRestrictedError) Following module cannot be defined/redefined: #{inspect(module)}"

        new_failure(:module_conflict, message, unsafe.atom_mapping)

      {:definition_conflict, name_arity, previous_def, previous_ctx, conflict_def, conflict_ctx} ->
        conflict_line = Keyword.get(conflict_ctx, :line)
        previous_line = Keyword.get(previous_ctx, :line)
        {name, arity} = name_arity

        message =
          "** (Dune.Eval.CompileError) nofile:#{conflict_line}: " <>
            "#{conflict_def} #{name}/#{arity} already defined as #{previous_def} in nofile:#{previous_line}"

        new_failure(:exception, message, unsafe.atom_mapping)

      {:parsing_error, ast} ->
        message = "dune parsing error: failed to safe parse\n         #{Macro.to_string(ast)}"
        new_failure(:parsing, message, unsafe.atom_mapping)

      {:exception, error} ->
        message = Exception.format(:error, error)
        new_failure(:exception, message, unsafe.atom_mapping)
    end
  end

  def sanitize(%Failure{} = failure, _opts), do: failure

  defp new_failure(type, message, atom_mapping) when is_atom(type) and is_binary(message) do
    failure = %Failure{type: type, message: message, stdio: ""}
    AtomMapping.replace_in_result(atom_mapping, failure)
  end

  # XXX this is a bit hacky and brute-force approach!
  # ideally the AST transformation is robust enough so we don't need it
  defp try_sanitize(ast, env) do
    do_sanitize_main(ast, env)
  rescue
    error ->
      error
      |> then(&Exception.blame(:error, &1, __STACKTRACE__))
      |> elem(0)
      |> then(&Exception.format(:error, &1))
      |> IO.warn()

      {:parsing_error, ast}
  catch
    thrown -> thrown
  end

  defp do_sanitize_main({:__block__, ctx, list}, env) do
    {list_ast, env} = do_sanitize_main_list(list, env)
    block_ast = {:__block__, ctx, list_ast}
    {:ok, block_ast, env}
  end

  defp do_sanitize_main(single, env) do
    case do_sanitize_main_list([single], env) do
      {[safe_single], env} ->
        {:ok, safe_single, env}

      {list_ast, env} when is_list(list_ast) ->
        block_ast = {:__block__, [], list_ast}
        {:ok, block_ast, env}
    end
  end

  defp do_sanitize_main_list(list, env) when is_list(list) do
    {defmodules, instructions} = Enum.split_with(list, &defmodule_block?/1)

    raw_fun_definitions = Enum.map(defmodules, &parse_module_definition/1)

    env =
      Enum.reduce(raw_fun_definitions, env, fn {module, fun_defs}, acc ->
        fun_name_arities =
          Map.new(fun_defs, fn {name_arity, [raw_definition | _]} ->
            {name_arity, elem(raw_definition, 0)}
          end)

        CompileEnv.define_fake_module(acc, module, fun_name_arities)
      end)

    module_definitions = Enum.map(raw_fun_definitions, &sanitize_module_definition(&1, env))

    sanitized_instructions =
      case {raw_fun_definitions, do_sanitize(instructions, env)} do
        {[_ | _], []} ->
          {last_module, _} = List.last(raw_fun_definitions)
          [quote(do: {:module, unquote(last_module), nil, nil})]

        {_, sanitized_instructions} ->
          sanitized_instructions
      end

    {module_definitions ++ sanitized_instructions, env}
  end

  defp defmodule_block?({:defmodule, _, _}), do: true
  defp defmodule_block?(_), do: false

  defp parse_module_definition(
         {:defmodule, _,
          [
            {:__aliases__, _, [_module_atom]} = module_def,
            [do: do_ast]
          ]}
       ) do
    module_name = Macro.expand_once(module_def, __ENV__)
    do_parse_module_definition(module_name, do_ast)
  end

  defp parse_module_definition({:defmodule, _, [module_name, [do: do_ast]]})
       when is_atom(module_name) do
    do_parse_module_definition(module_name, do_ast)
  end

  defp parse_module_definition(ast = {:defmodule, _, _}) do
    throw({:parsing_error, ast})
  end

  defp do_parse_module_definition(module_name, do_ast) do
    fun_definitions =
      block_to_list(do_ast)
      |> Enum.map(&parse_fun_definition/1)
      |> Enum.filter(& &1)
      |> Enum.flat_map(&expand_defaults/1)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> tap(&check_definition_conflicts/1)

    {module_name, fun_definitions}
  end

  defp block_to_list({:__block__, _, list}) when is_list(list), do: list
  defp block_to_list(single) when is_tuple(single), do: [single]

  defp parse_fun_definition({def_or_defp, ctx, [signature, [do: body]]})
       when def_or_defp in [:def, :defp] do
    {header, guards} = parse_fun_signature(signature)
    {name, args} = Macro.decompose_call(header)
    {args, defaults} = extract_default_args(args, 0, [], [])
    name_arity = {name, length(args)}
    definition = {def_or_defp, ctx, args, body, guards}
    {name_arity, definition, defaults}
  end

  defp parse_fun_definition({:@, _, [{doc, _, [value]}]})
       when doc in ~w[moduledoc doc]a and (value == false or is_binary(value)) do
    nil
  end

  defp parse_fun_definition({:@, _, [{typespec, _, [{:"::", _, _}]}]})
       when typespec in ~w[spec type typep opaque]a do
    nil
  end

  defp parse_fun_definition(unsupported_ast) do
    throw({:module_restricted, unsupported_ast})
  end

  # TODO else raise unsupported!

  defp extract_default_args([], _index, arg_acc, defaults) do
    {Enum.reverse(arg_acc), defaults}
  end

  defp extract_default_args([{:\\, _, [arg, default]} | args], index, arg_acc, defaults) do
    extract_default_args(args, index + 1, [arg | arg_acc], [{index, default} | defaults])
  end

  defp extract_default_args([arg | args], index, arg_acc, defaults) do
    extract_default_args(args, index + 1, [arg | arg_acc], defaults)
  end

  defp expand_defaults({name_arity, definition, _defaults = []}) do
    [{name_arity, definition}]
  end

  defp expand_defaults({name_arity = {name, arity}, definition, defaults}) do
    def_or_defp = elem(definition, 0)
    do_expand_defaults(name, arity, def_or_defp, defaults, [{name_arity, definition}])
  end

  defp do_expand_defaults(_name, _arity, _def_or_defp, [], acc) do
    acc
  end

  defp do_expand_defaults(
         name,
         arity,
         def_or_defp,
         [{default_index, default_value} | defaults],
         acc
       ) do
    args = Macro.generate_arguments(arity, nil)
    arity = arity - 1

    args_without_default = List.delete_at(args, default_index)

    args_in_expr =
      Enum.with_index(args, fn
        _arg, ^default_index -> default_value
        arg, _index -> arg
      end)

    definition = {def_or_defp, [], args_without_default, {name, [], args_in_expr}, nil}

    acc = [{{name, arity}, definition} | acc]

    do_expand_defaults(name, arity, def_or_defp, defaults, acc)
  end

  defp check_definition_conflicts(grouped_definitions) do
    Enum.each(grouped_definitions, fn {name_arity, [head | tail]} ->
      check_definition_conflict(name_arity, head, tail)
    end)
  end

  defp check_definition_conflict(_name_arity, _, []), do: :ok

  defp check_definition_conflict(
         name_arity,
         head = {def_or_defp, _, _, _, _},
         [
           {def_or_defp, _, _, _, _} | rest
         ]
       ) do
    check_definition_conflict(name_arity, head, rest)
  end

  defp check_definition_conflict(name_arity, {previous_def, previous_ctx, _, _, _}, [
         {conflict_def, conflict_ctx, _, _, _} | _
       ]) do
    throw(
      {:definition_conflict, name_arity, previous_def, previous_ctx, conflict_def, conflict_ctx}
    )
  end

  defp parse_fun_signature({:when, _, [header, guards]}) do
    {header, guards}
  end

  defp parse_fun_signature(header) do
    {header, nil}
  end

  defp sanitize_module_definition({module, fun_defs}, env) do
    env = %{env | module: module}

    public_funs_ast =
      fun_defs
      |> Enum.map(&sanitize_fun(&1, env))
      |> Enum.group_by(&elem(&1, 0), fn {_fun, arity, ast} -> {arity, ast} end)
      |> Enum.map(fn {fun_name, list} ->
        {fun_name, to_map_ast(list)}
      end)
      |> to_map_ast()

    quote do
      unquote(env_variable()) =
        Dune.Eval.Env.add_module(
          unquote(env_variable()),
          unquote(module),
          %Dune.Eval.FakeModule{public_funs: unquote(public_funs_ast)}
        )
    end
  end

  defp to_map_ast(list_ast) when is_list(list_ast), do: {:%{}, [], list_ast}

  defp sanitize_fun({{fun_name, arity}, definitions}, env) do
    args = Macro.var(:args, nil)

    bottom_clause =
      quote do
        args ->
          raise %Dune.Eval.FunctionClauseError{
            module: unquote(env.module),
            function: unquote(fun_name),
            args: args
          }
      end

    clauses = Enum.map(definitions, &sanitize_fun_clause(&1, env)) ++ bottom_clause
    env_var = env_variable_if_used(clauses)

    anonymous_ast =
      {:fn, [],
       [
         {:->, [],
          [
            [env_var, args],
            {:case, [],
             [
               args,
               [do: clauses]
             ]}
          ]}
       ]}

    {fun_name, arity, anonymous_ast}
  end

  defp sanitize_fun_clause({_def_or_defp, ctx, args, body, guards}, env) do
    safe_args = do_sanitize(args, env)
    safe_body = do_sanitize(body, env)
    safe_guards = do_sanitize(guards, env)
    definition_to_clause(ctx, safe_args, safe_body, safe_guards)
  end

  defp definition_to_clause(ctx, args, body, _guards = nil) do
    {:->, ctx, [[args], body]}
  end

  defp definition_to_clause(ctx, args, body, guards) when is_tuple(guards) do
    args_and_guards = [{:when, [], [args, guards]}]
    {:->, ctx, [args_and_guards, body]}
  end

  defp env_variable_if_used(asts) do
    uses_variable?(asts, @env_variable_name)

    case uses_variable?(asts, @env_variable_name) do
      true -> env_variable()
      false -> underscore_env_variable()
    end
  end

  defp uses_variable?([], _variable_name), do: false

  defp uses_variable?([head | tail], variable_name) do
    case uses_variable?(head, variable_name) do
      true -> true
      false -> uses_variable?(tail, variable_name)
    end
  end

  defp uses_variable?({variable_name, _, nil}, variable_name), do: true

  defp uses_variable?({_, _, list}, variable_name) when is_list(list) do
    uses_variable?(list, variable_name)
  end

  defp uses_variable?({x, y}, variable_name) do
    uses_variable?(x, variable_name) or uses_variable?(y, variable_name)
  end

  defp uses_variable?(_ast, _variable_name), do: false

  defp do_sanitize(ast, env)

  defp do_sanitize(raw_value, _env)
       when is_atom(raw_value) or is_number(raw_value) or is_binary(raw_value) do
    raw_value
  end

  defp do_sanitize(list, env)
       when is_list(list) do
    sanitize_args(list, env)
  end

  defp do_sanitize({arg1, arg2}, env) do
    [safe_arg1, safe_arg2] = sanitize_args([arg1, arg2], env)
    {safe_arg1, safe_arg2}
  end

  defp do_sanitize({atom, _, _} = raw, env) when atom in [:__block__, :when, :<-, :->, :|] do
    sanitize_args_in_node(raw, env)
  end

  defp do_sanitize({name, _, atom} = variable, _env)
       when is_atom(name) and atom in [nil, Elixir] do
    unless authorized_var_name?(name) do
      throw({:restricted, Kernel, name, 0})
    end

    variable
  end

  defp do_sanitize({:&, _, args}, env) do
    [ast] = args

    sanitize_capture(ast, env)
  end

  defp do_sanitize({{:., _, [left, right]}, ctx, args} = raw, env)
       when is_atom(right) and is_list(args) do
    case left do
      atom when is_atom(atom) ->
        do_sanitize_function(raw, env)

      {:__aliases__, _, list} when is_list(list) ->
        do_sanitize_function(raw, env)

      _ ->
        do_sanitize_dot(left, right, args, ctx, env)
    end
  end

  defp do_sanitize({{:., dot_ctx, [{fn_or_ampersand, _, _} = anonymous]}, ctx, args}, env)
       when fn_or_ampersand in [:fn, :&] do
    safe_anonymous = do_sanitize(anonymous, env)
    safe_args = sanitize_args(args, env)
    {{:., dot_ctx, [safe_anonymous]}, ctx, safe_args}
  end

  defp do_sanitize({:|>, _, _} = ast, env) do
    case try_expand_once(ast) do
      {:ok, {atom, _, _} = expanded} when atom != :|> ->
        do_sanitize(expanded, env)

      {:error, error} ->
        throw({:exception, error})
    end
  end

  defp do_sanitize({_, _, args} = raw, env) when is_list(args) do
    do_sanitize_function(raw, env)
  end

  defp try_expand_once(ast) do
    {:ok, Macro.expand_once(ast, __ENV__)}
  rescue
    error ->
      {:error, error}
  end

  defp do_sanitize_dot(left, key, args, ctx, env) do
    safe_left = do_sanitize(left, env)
    safe_args = sanitize_args(args, env)

    if args == [] and {:no_parens, true} in ctx do
      quote do
        Dune.Shims.Kernel.safe_dot(
          unquote(env_variable()),
          unquote(safe_left),
          unquote(key)
        )
      end
    else
      quote do
        Dune.Shims.Kernel.safe_apply(
          unquote(env_variable()),
          unquote(safe_left),
          unquote(key),
          unquote(safe_args)
        )
      end
    end
  end

  defp do_sanitize_function({func, ctx, atom}, env) when atom in [nil, Elixir] do
    do_sanitize_function({func, ctx, []}, env)
  end

  defp do_sanitize_function({{:., _, [{_variable_function, _, atom}]}, _, args} = raw, env)
       when atom in [nil, Elixir] and is_list(args) do
    sanitize_args_in_node(raw, env)
  end

  defp do_sanitize_function({func, _, args} = raw, env)
       when is_list(args) do
    {module, func_name} = extract_module_and_fun(func)

    arity = length(args)

    case CompileEnv.resolve_mfa(env, module, func_name, arity) do
      {:restricted, resolved_module} ->
        throw({:restricted, resolved_module, func_name, arity})

      {:shimmed, shim_module, shim_func} ->
        safe_args = sanitize_args(args, env)

        quote do
          unquote(shim_module).unquote(shim_func)(
            unquote(env_variable()),
            unquote_splicing(safe_args)
          )
        end

      {:fake, fake_module} ->
        safe_args = sanitize_args(args, env)

        quote do
          Dune.Eval.Env.apply_fake(
            unquote(env_variable()),
            unquote(fake_module),
            unquote(func_name),
            unquote(safe_args)
          )
        end

      :allowed ->
        sanitize_args_in_node(raw, env)

      :undefined_module ->
        throw({:undefined_module, module, func_name, arity})

      :undefined_function ->
        throw({:undefined_function, module, func_name, arity})
    end
  end

  defp extract_module_and_fun({:., _, [{:__aliases__, _, modules}, func_name]}) do
    {modules |> Module.concat(), func_name}
  end

  defp extract_module_and_fun({:., _, [erlang_module, func_name]}) when is_atom(erlang_module) do
    {erlang_module, func_name}
  end

  defp extract_module_and_fun(func_name) when is_atom(func_name) do
    {nil, func_name}
  end

  defp sanitize_capture({:/, _, [{func, _, _}, arity]} = raw, env) when is_integer(arity) do
    {module, func_name} = extract_module_and_fun(func)

    case CompileEnv.resolve_mfa(env, module, func_name, arity) do
      {:restricted, resolved_module} ->
        throw({:restricted, resolved_module, func_name, arity})

      {:fake, fake_module} ->
        args = Macro.generate_unique_arguments(arity, nil)

        quote do
          fn unquote_splicing(args) ->
            Dune.Eval.Env.apply_fake(
              unquote(env_variable()),
              unquote(fake_module),
              unquote(func_name),
              unquote(args)
            )
          end
        end

      {:shimmed, shim_module, shim_func} ->
        args = Macro.generate_unique_arguments(arity, nil)

        quote do
          # FIXME pass env here!
          fn unquote_splicing(args) ->
            unquote(shim_module).unquote(shim_func)(
              unquote(env_variable()),
              unquote_splicing(args)
            )
          end
        end

      :allowed ->
        {:&, [], [raw]}

      :undefined_module ->
        throw({:undefined_module, module, func_name, arity})

      :undefined_function ->
        throw({:undefined_function, module, func_name, arity})
    end
  end

  defp sanitize_capture(capture_arg, env) do
    safe_capture_arg = do_sanitize(capture_arg, env)
    {:&, [], [safe_capture_arg]}
  end

  defp sanitize_args(args, env) when is_list(args) do
    Enum.map(args, &do_sanitize(&1, env))
  end

  defp sanitize_args_in_node({_, _, args} = raw, env) when is_list(args) do
    safe_args = sanitize_args(args, env)
    put_elem(raw, 2, safe_args)
  end

  defp env_variable do
    Macro.var(@env_variable_name, nil)
  end

  defp underscore_env_variable do
    Macro.var(:_env__Dune__, nil)
  end

  defp authorized_var_name?(name) do
    # e.g. recompile could be interpreted as recompile/0
    not (RealModule.fun_exists?(Kernel, name, 0) or Macro.special_form?(name, 0))
  end
end
