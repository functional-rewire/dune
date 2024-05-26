defmodule Dune do
  @moduledoc """
  A sandbox for Elixir to safely evaluate untrusted code from user input.

  ## Features

  - only authorized modules and functions can be executed (see
  `Dune.Allowlist.Default`)
  - no access to environment variables, file system, network...
  - code executed in an isolated process
  - execution within configurable limits: timeout, maximum reductions and memory
  (inspired by [Luerl](https://github.com/rvirding/luerl))
  - captured standard output
  - atoms, without atom leaks: parsing and runtime do not
  [leak atoms](https://hexdocs.pm/elixir/String.html#to_atom/1) (i.e. does not
  keep
  [filling the atom table](https://learnyousomeerlang.com/starting-out-for-real#atoms)
  until the VM crashes)
  - modules, without actual module creation: Dune does not let users define any
  actual module (would leak memory and modify the state of the VM globally), but
  `defmodule` simulates the basic behavior of a module, including private and
  recursive functions

  The list of modules and functions authorized by default is defined by the
  `Dune.Allowlist.Default` module, but this list can be extended and customized
  (at your own risk!) using `Dune.Allowlist`.

  If you need to keep the state between evaluations, you might consider
  `Dune.Session`.

  """

  alias Dune.{Success, Failure, Parser, Eval, Opts}

  @doc ~S"""
  Evaluates the `string` in the sandbox.

  Available options are detailed in `Dune.Opts`.

  Returns a `Dune.Success` struct if the execution went successfully,
  a `Dune.Failure` else.

  ## Examples

      iex> Dune.eval_string("IO.puts(\"Hello world!\")")
      %Dune.Success{inspected: ":ok", stdio: "Hello world!\n", value: :ok}

      iex> Dune.eval_string("File.cwd!()")
      %Dune.Failure{message: "** (DuneRestrictedError) function File.cwd!/0 is restricted", type: :restricted}

      iex> Dune.eval_string("List.duplicate(:spam, 100_000)")
      %Dune.Failure{message: "Execution stopped - memory limit exceeded", stdio: "", type: :memory}

      iex> Dune.eval_string("Foo.bar()")
      %Dune.Failure{message: "** (UndefinedFunctionError) function Foo.bar/0 is undefined (module Foo is not available)", type: :exception}

      iex> Dune.eval_string("][")
      %Dune.Failure{message: "unexpected token: ]", type: :parsing}

  Atoms used during parsing and execution might be transformed to prevent atom leaks:

      iex> Dune.eval_string("some_variable = IO.inspect(:some_atom)")
      %Dune.Success{inspected: ":some_atom", stdio: ":some_atom\n", value: :a__Dune_atom_2__}

  The `value` field shows the actual runtime value, but `inspected` and `stdio` are safe to display to the user.

  """
  @spec eval_string(String.t(), Keyword.t()) :: Success.t() | Failure.t()
  def eval_string(string, opts \\ []) when is_binary(string) do
    opts = Opts.validate!(opts)

    string
    |> Parser.parse_string(opts)
    |> Eval.run(opts)
  end

  @doc ~S"""
  Evaluates the quoted `ast` in the sandbox.

  Available options are detailed in `Dune.Opts` (parsing restrictions have no effect)..

  Returns a `Dune.Success` struct if the execution went successfully,
  a `Dune.Failure` else.

  ## Examples

      iex> Dune.eval_quoted(quote do: [1, 2] ++ [3, 4])
      %Dune.Success{inspected: "[1, 2, 3, 4]", stdio: "", value: [1, 2, 3, 4]}

      iex> Dune.eval_quoted(quote do: System.get_env())
      %Dune.Failure{message: "** (DuneRestrictedError) function System.get_env/0 is restricted", type: :restricted}

      iex> Dune.eval_quoted(quote do: Process.sleep(500))
      %Dune.Failure{message: "Execution timeout - 50ms", type: :timeout}

  """
  @spec eval_quoted(Macro.t(), Keyword.t()) :: Success.t() | Failure.t()
  def eval_quoted(ast, opts \\ []) do
    opts = Opts.validate!(opts)

    ast
    |> Parser.parse_quoted(opts)
    |> Eval.run(opts)
  end

  @doc ~S"""
  Returns the AST corresponding to the provided `string`, without leaking atoms.

  Available options are detailed in `Dune.Opts` (runtime restrictions have no effect).

  Returns a `Dune.Success` struct if the execution went successfully,
  a `Dune.Failure` else.

  ## Examples

      iex> Dune.string_to_quoted("1 + 2")
      %Dune.Success{inspected: "{:+, [line: 1], [1, 2]}", stdio: "", value: {:+, [line: 1], [1, 2]}}

      iex> Dune.string_to_quoted("[invalid")
      %Dune.Failure{stdio: "", message: "missing terminator: ]", type: :parsing}

  The `pretty` option can make the AST more readable by adding newlines to `inspected`:

      iex> Dune.string_to_quoted("IO.puts(:hello)", pretty: true).inspected
      "{{:., [line: 1], [{:__aliases__, [line: 1], [:IO]}, :puts]}, [line: 1],\n [:hello]}"

      iex> Dune.string_to_quoted("IO.puts(:hello)").inspected
      "{{:., [line: 1], [{:__aliases__, [line: 1], [:IO]}, :puts]}, [line: 1], [:hello]}"

  Since the code isn't executed, there is no allowlist restriction:

      iex> Dune.string_to_quoted("System.halt()")
      %Dune.Success{
        inspected: "{{:., [line: 1], [{:__aliases__, [line: 1], [:System]}, :halt]}, [line: 1], []}",
        stdio: "",
        value: {{:., [line: 1], [{:__aliases__, [line: 1], [:System]}, :halt]}, [line: 1], []}
      }

  Atoms might be transformed during parsing to prevent atom leaks:

      iex> Dune.string_to_quoted("some_variable = :some_atom")
      %Dune.Success{
        inspected: "{:=, [line: 1], [{:some_variable, [line: 1], nil}, :some_atom]}",
        stdio: "",
        value: {:=, [line: 1], [{:a__Dune_atom_1__, [line: 1], nil}, :a__Dune_atom_2__]}
      }

  The `value` field shows the actual runtime value, but `inspected` is safe to display to the user.

  """
  @spec string_to_quoted(String.t(), Keyword.t()) :: Success.t() | Failure.t()
  def string_to_quoted(string, opts \\ []) when is_binary(string) do
    opts = Opts.validate!(opts)
    Parser.string_to_quoted(string, opts)
  end
end
