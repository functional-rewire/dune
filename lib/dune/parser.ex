defmodule Dune.Parser do
  @moduledoc false

  alias Dune.{AtomMapping, Success, Failure, Opts}
  alias Dune.Parser.{CompileEnv, StringParser, Sanitizer, SafeAst, UnsafeAst}

  @typep previous_session :: %{
           atom_mapping: AtomMapping.t(),
           compile_env: Dune.Parser.CompileEnv.t()
         }

  @spec parse_string(String.t(), Opts.t(), previous_session | nil) :: SafeAst.t() | Failure.t()
  def parse_string(string, opts = %Opts{}, previous_session \\ nil) when is_binary(string) do
    compile_env = get_compile_env(opts, previous_session)

    string
    |> do_parse_string(opts, previous_session)
    |> Sanitizer.sanitize(compile_env)
  end

  defp do_parse_string(string, opts = %{max_length: max_length}, previous_session) do
    case String.length(string) do
      length when length > max_length ->
        %Failure{type: :parsing, message: "max code length exceeded: #{length} > #{max_length}"}

      _ ->
        StringParser.parse_string(string, opts, previous_session)
    end
  end

  @spec parse_quoted(Macro.t(), Opts.t(), previous_session | nil) :: SafeAst.t()
  def parse_quoted(quoted, opts = %Opts{}, previous_session \\ nil) do
    compile_env = get_compile_env(opts, previous_session)

    quoted
    |> unsafe_quoted()
    |> Sanitizer.sanitize(compile_env)
  end

  def unsafe_quoted(ast) do
    %UnsafeAst{ast: ast, atom_mapping: AtomMapping.new()}
  end

  defp get_compile_env(opts, nil) do
    CompileEnv.new(opts.allowlist)
  end

  defp get_compile_env(opts, %{compile_env: compile_env}) do
    %{compile_env | allowlist: opts.allowlist}
  end

  @spec string_to_quoted(String.t(), Opts.t()) :: Success.t() | Failure.t()
  def string_to_quoted(string, opts) do
    with unsafe = %UnsafeAst{} <- StringParser.parse_string(string, opts, nil, false) do
      inspected = inspect(unsafe.ast, pretty: opts.pretty)
      inspected = AtomMapping.replace_in_string(unsafe.atom_mapping, inspected)

      %Success{
        value: unsafe.ast,
        inspected: inspected,
        stdio: ""
      }
    end
  end
end
