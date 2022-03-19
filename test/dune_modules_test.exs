defmodule DuneModulesTest do
  use ExUnit.Case, async: true

  alias Dune.{Success, Failure}

  defmacro sigil_E(call, _expr) do
    # TODO fix memory needs
    quote do
      Dune.eval_string(unquote(call), max_reductions: 25_000, max_heap_size: 30_000)
    end
  end

  describe "Dune authorized" do
    test "basic module" do
      result = ~E'''
      defmodule Hello do
        def greet(value) do
          IO.puts "Hello #{value}"
        end
      end

      Hello.greet(:world!)
      '''

      assert %Success{value: :ok, stdio: "Hello world!\n"} = result
    end

    test "plain atom module" do
      result = ~E'''
      defmodule :hello do
        def greet(value) do
          IO.puts "Hello #{value}"
        end
      end

      :hello.greet(:world!)
      '''

      assert %Success{value: :ok, stdio: "Hello world!\n"} = result
    end

    test "module without other code" do
      result = ~E'''
      defmodule Hello do
      end
      '''

      assert %Success{
               value: {:module, Dune_Module_1__, nil, nil},
               inspected: "{:module, Hello, nil, nil}",
               stdio: ""
             } = result
    end

    test "default argument" do
      result = ~E'''
      defmodule My.Default do
        def incr(x \\ 0), do: x + 1
      end

      [My.Default.incr(), My.Default.incr(100)]
      '''

      assert %Success{value: [1, 101]} = result
    end

    test "default arguments" do
      result = ~E'''
      defmodule My.Defaults do
        def defaults(a \\ 1, b \\ 2, c) do
          [a, b, c]
        end
      end

      {My.Defaults.defaults(:c), My.Defaults.defaults(:a, :c)}
      '''

      assert %Success{value: {[1, 2, :c], [:a, 2, :c]}} = result
    end

    test "recursive functions with guards" do
      result = ~E'''
      defmodule My.List do
        def my_sum([]), do: 0
        def my_sum([h | t]) when is_number(h), do: h + my_sum(t)
      end

      My.List.my_sum([1, 100, 1000])
      '''

      assert %Success{value: 1101} = result
    end

    test "recursive functions in a nested block" do
      result = ~E'''
      defmodule My.List do
        def my_sum([]), do: 0
        def my_sum([h | t]) do
          if is_number(h) do
            h + my_sum(t)
          else
            :NaN
          end
        end
      end

      My.List.my_sum([1, 100, 1000])
      '''

      assert %Success{value: 1101} = result
    end

    test "public and private functions" do
      assert %Success{value: "success!"} = ~E'''
             defmodule My.Module do
               def public, do: private()
               defp private, do: "success!"
             end

             My.Module.public
             '''
    end

    test "recursive private function with guards" do
      result = ~E'''
      defmodule My.List do
        def my_sum(list) when is_list(list), do: my_sum(list, 0)
        defp my_sum([], acc), do: acc
        defp my_sum([h | t], acc) when is_number(h), do: my_sum(t, h + acc)
      end

      My.List.my_sum([1, 100, 1000])
      '''

      assert %Success{value: 1101} = result
    end

    test "captured fake module functions (external)" do
      assert %Success{value: ["Joe (20)", "Jane (27)"]} = ~E'''
             defmodule My.Captures do
               def format(%{name: name, age: age}) do
                "#{name} (#{age})"
               end
             end

             Enum.map(
               [%{name: "Joe", age: 20}, %{name: "Jane", age: 27}],
               &My.Captures.format/1
             )
             '''

      assert %Success{inspected: ":foo"} = ~E'''
             defmodule My.Captures do
               def const, do: :foo
             end

             f = &My.Captures.const/0
             f.()
             '''
    end

    test "captured fake module functions (internal)" do
      assert %Success{value: ["Joe (20)", "Jane (27)"]} = ~E'''
             defmodule My.Captures do
               def format_many(list) do
                 Enum.map(list, &format_one/1)
               end

               def format_one(%{name: name, age: age}) do
                 "#{name} (#{age})"
               end
             end

             My.Captures.format_many([%{name: "Joe", age: 20}, %{name: "Jane", age: 27}])
             '''
    end

    test "apply fake module functions" do
      assert %Success{value: "Joe (20)"} = ~E'''
             defmodule My.Formatter do
               def format(%{name: name, age: age}) do
                "#{name} (#{age})"
               end
             end

             apply(
               My.Formatter,
               :format,
               [%{name: "Joe", age: 20}]
             )
             '''
    end

    test "accept docs and typespecs" do
      assert %Success{value: "Joe (20)"} = ~E'''
             defmodule My.Formatter do
               @moduledoc "Format all the things!"

               @typep name :: String.t()
               @type user :: %{name: name, age: integer}

               @doc "Formats a user"
               @spec format(user) :: String.t()
               def format(%{name: name, age: age}) do
                "#{name} (#{age})"
               end
             end

             My.Formatter.format(%{name: "Joe", age: 20})
             '''
    end

    test "0-arity call without parenthesis" do
      assert %Success{value: "success!"} = ~E'''
             defmodule My.Module do
               def public, do: private()
               defp private, do: "success!"
             end

             My.Module.public
             '''
    end

    # TODO: apply private function
  end

  describe "exceptions" do
    test "function clause error" do
      assert %Failure{
               type: :exception,
               message:
                 "** (Dune.Eval.FunctionClauseError) no function clause matching in My.Checker.check_age/1: My.Checker.check_age(:invalid)"
             } = ~E'''
             defmodule My.Checker do
               def check_age(age) when is_integer(age) and age >= 18, do: :ok
             end

             My.Checker.check_age(:invalid)
             '''
    end

    test "calling private function" do
      assert %Failure{
               type: :exception,
               message:
                 "** (UndefinedFunctionError) function My.Module.private/0 is undefined or private"
             } = ~E'''
             defmodule My.Module do
               def public, do: :public
               defp private, do: :private
             end

             My.Module.private
             '''
    end

    test "conflicting public and private functions" do
      assert %Failure{
               type: :exception,
               message:
                 "** (Dune.Eval.CompileError) nofile:3: defp conflicting/0 already defined as def in nofile:2"
             } = ~E'''
             defmodule My.Module do
               def conflicting, do: "public"
               defp conflicting, do: "private"
             end
             '''
    end
  end

  describe "Dune restricted" do
    test "unsafe function body" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function System.get_env/0 is restricted"
             } = ~E'''
             defmodule Danger do
               def danger() do
                 System.get_env()
               end
             end

             Danger.danger()
             '''
    end

    test "unsafe function default arg" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function System.get_env/0 is restricted"
             } = ~E'''
             defmodule Danger do
               def danger(env \\ System.get_env()) do
                 env
               end
             end

             Danger.danger()
             '''
    end

    test "restrictions in the module top level" do
      assert %Failure{
               type: :module_restricted,
               message:
                 "** (DuneRestrictedError) the following syntax is restricted inside defmodule:\n         def no_block"
             } = ~E'''
             defmodule My.Module do
               def no_block
             end
             '''

      assert %Failure{
               type: :module_restricted,
               message:
                 "** (DuneRestrictedError) the following syntax is restricted inside defmodule:\n         @foo 1 + 1"
             } = ~E'''
             defmodule My.Module do
               @foo 1 + 1
             end
             '''
    end

    test "trying to redefine existing module" do
      assert %Failure{
               type: :module_conflict,
               message:
                 "** (DuneRestrictedError) Following module cannot be defined/redefined: System"
             } = ~E'''
             defmodule System do
               def foo, do: :bar
             end
             '''

      assert %Failure{
               type: :module_conflict,
               message:
                 "** (DuneRestrictedError) Following module cannot be defined/redefined: String"
             } = ~E'''
             defmodule String do
               def foo, do: :bar
             end
             '''

      assert %Failure{
               type: :module_conflict,
               message:
                 "** (DuneRestrictedError) Following module cannot be defined/redefined: ExUnit"
             } = ~E'''
             defmodule ExUnit do
               def foo, do: :bar
             end
             '''

      assert %Failure{
               type: :module_conflict,
               message:
                 "** (DuneRestrictedError) Following module cannot be defined/redefined: Foo"
             } = ~E'''
             defmodule Foo do
               def foo, do: :bar
             end
             defmodule Foo do
               def foo, do: :bar
             end
             '''
    end

    test "defmodule used with different arities" do
      assert %Failure{
               type: :parsing,
               message: "dune parsing error: failed to safe parse\n         defmodule"
             } = ~E'defmodule'

      assert %Failure{
               type: :parsing,
               message: "dune parsing error: failed to safe parse\n         defmodule do\n" <> _
             } = ~E'''
             defmodule do
               def foo, do: :bar
             end
             '''
    end
  end
end
