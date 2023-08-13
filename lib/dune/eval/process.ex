defmodule Dune.Eval.Process do
  @moduledoc false

  alias Dune.Failure

  def run(fun, opts = %Dune.Opts{}) when is_function(fun, 0) do
    with_string_io(fn string_io ->
      do_run(fun, opts, string_io)
    end)
  end

  defp do_run(fun, opts, string_io) do
    task =
      Task.async(fn ->
        # spawn within a task to avoid trapping exits in the caller
        spawn_trapped_process(
          fun,
          opts.max_heap_size,
          opts.max_reductions,
          string_io
        )
      end)

    result =
      case Task.yield(task, opts.timeout) || Task.shutdown(task) do
        {:ok, result} ->
          result

        nil ->
          %Failure{type: :timeout, message: "Execution timeout - #{opts.timeout}ms"}
      end

    case result do
      %Failure{type: :compile_error} -> result
      _ -> %{result | stdio: result.stdio <> StringIO.flush(string_io)}
    end
  end

  defp with_string_io(fun) do
    {:ok, string_io} = StringIO.open("")

    try do
      fun.(string_io)
    after
      StringIO.close(string_io)
    end
  end

  # returns a Dune.Failure struct or exits
  defp spawn_trapped_process(fun, max_heap_size, max_reductions, string_io) do
    report_to = self()

    Process.flag(:trap_exit, true)

    # unlike plain spawn / Process.spawn, proc_lib doesn't trigger the logger:
    # |  Unlike in "plain Erlang", proc_lib processes will not generate error reports,
    # |  which are written to the terminal by the emulator. All exceptions are converted
    # |  to exits which are ignored by the default logger handler.

    opts = [
      :link,
      priority: :low,
      max_heap_size: %{size: max_heap_size, kill: true, error_logger: false}
    ]

    pid =
      :proc_lib.spawn_opt(
        fn ->
          Process.group_leader(self(), string_io)

          fun
          |> catch_diagnostics()
          |> then(&send(report_to, &1))
        end,
        opts
      )

    spawn(fn -> check_max_reductions(pid, report_to, max_reductions) end)

    receive do
      {:ok, result, diagnostics} ->
        prepend_diagnostics(result, diagnostics)

      {:compile_error, error, diagnostics, stacktrace} ->
        format_compile_error(error, diagnostics, stacktrace)

      {:EXIT, ^pid, reason} ->
        case reason do
          :normal ->
            exit(:normal)

          :killed ->
            %Failure{type: :memory, message: "Execution stopped - memory limit exceeded"}

          {error, stacktrace} ->
            format_error(error, stacktrace)
        end

      {:EXIT, _other_pid, reason} ->
        # avoid the process to become immune to parent death
        exit(reason)

      {:reductions_exceeded, _reductions} ->
        %Failure{type: :reductions, message: "Execution stopped - reductions limit exceeded"}
    end
  end

  # TODO remove then dropping support for 1.14
  if System.version() |> Version.compare("1.15.0") != :lt do
    defp catch_diagnostics(fun) do
      with_diagnostics =
        Code.with_diagnostics(fn ->
          try do
            {:ok, fun.()}
          rescue
            err in CompileError ->
              {err, __STACKTRACE__}
          end
        end)

      case with_diagnostics do
        {{:ok, result}, diagnostics} ->
          {:ok, result, diagnostics}

        {{%CompileError{} = err, stacktrace}, diagnostics} ->
          {:compile_error, err, diagnostics, stacktrace}
      end
    end
  else
    defp catch_diagnostics(fun) do
      try do
        {:ok, fun.(), []}
      rescue
        err in CompileError ->
          {:compile_error, err, [], __STACKTRACE__}
      end
    end
  end

  defp check_max_reductions(pid, report_to, max_reductions) when is_integer(max_reductions) do
    # approach inspired from luerl
    # https://github.com/rvirding/luerl/blob/develop/src/luerl_sandbox.erl
    case Process.info(pid, :reductions) do
      nil ->
        :ok

      {:reductions, reductions} when reductions > max_reductions ->
        # if send immediately, might arrive before an EXIT signal
        Process.send_after(report_to, {:reductions_exceeded, reductions}, 1)

      {:reductions, _reductions} ->
        check_max_reductions(pid, report_to, max_reductions)
    end
  end

  defp format_error(error, stacktrace)

  defp format_error({:nocatch, value}, _stacktrace) do
    case value do
      {:undefined_module, module, fun, arity} -> Failure.undefined_module(module, fun, arity)
      {:undefined_function, module, fun, arity} -> Failure.undefined_function(module, fun, arity)
      {:safe_throw, thrown} -> %Failure{type: :throw, message: "** (throw) " <> inspect(thrown)}
    end
  end

  defp format_error(error, stacktrace) do
    [head | _] = stacktrace

    parts =
      case head do
        {:erl_eval, :do_apply, _, _} -> 3
        {:elixir_eval, :__FILE__, _, _} -> 3
        _ -> 2
      end

    message =
      {error, [head]}
      |> Exception.format_exit()
      |> String.split("\n    ", parts: parts)
      |> Enum.at(1)

    # TODO properly pass stacktrace
    %Failure{type: :exception, message: message}
  end

  defp format_compile_error(error, diagnostics, stacktrace) do
    message =
      {error, stacktrace}
      |> Exception.format_exit()
      |> String.split("\n    ")
      |> Enum.at(1)

    %Failure{
      type: :compile_error,
      message: message,
      stdio: format_diagnostics(diagnostics)
    }
  end

  defp prepend_diagnostics(result, []), do: result

  defp prepend_diagnostics(result, diagnostics) do
    %{result | stdio: format_diagnostics(diagnostics) <> "\n\n"}
  end

  defp format_diagnostics(diagnostics) do
    Enum.map_join(
      diagnostics,
      "\n",
      &"#{&1.severity}: #{&1.message}\n  #{&1.file}:#{&1.position}"
    )
  end
end
