defmodule DuneQuotedTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Dune.{Success, Failure}

  defmacrop dune(do: ast) do
    escaped_ast = Macro.escape(ast)

    quote do
      unquote(escaped_ast) |> Dune.eval_quoted(timeout: 100)
    end
  end

  describe "Dune authorized" do
    test "simple operations" do
      assert %Success{value: 5} = dune(do: 2 + 3)
      assert %Success{value: 15} = dune(do: 5 * 3)
      assert %Success{value: 0.5} = dune(do: 1 / 2)
      assert %Success{value: [1, 2, 3, 4]} = dune(do: [1, 2] ++ [3, 4])
      assert %Success{value: "abcd"} = dune(do: "ab" <> "cd")
    end

    test "basic Kernel functions" do
      assert %Success{value: 10} = dune(do: max(5, 10))
      assert %Success{value: "foo"} = dune(do: to_string(:foo))
      assert %Success{value: true} = dune(do: is_atom(:foo))
    end

    test "Kernel guards" do
      assert %Success{value: false} = dune(do: is_binary(55))
      assert %Success{value: true} = dune(do: is_number(55))
    end

    test "basic String functions" do
      assert %Success{value: "JoJo"} = dune(do: String.replace("jojo", "j", "J"))
    end

    test "basic Map functions" do
      assert %Success{value: %{foo: 5}} = dune(do: Map.put(%{}, :foo, 5))
      assert %Success{value: %{}} = dune(do: Map.new())
    end

    test "basic :math functions" do
      assert %Success{value: 3.0} = dune(do: :math.log10(1000))
      assert %Success{value: 3.141592653589793} = dune(do: :math.pi())
    end

    test "tuples" do
      assert %Success{value: {}} = dune(do: {})
      assert %Success{value: {:foo}} = dune(do: {:foo})
      assert %Success{value: {"hello", ~c"world"}} = dune(do: {"hello", ~c"world"})
      assert %Success{value: {1, 2, 3}} = dune(do: {1, 2, 3})
    end

    test "map operations" do
      assert %Success{value: %{a: :foo, b: 6}} =
               (dune do
                  map = %{a: 5, b: 6}
                  %{map | a: :foo}
                end)

      assert %Success{value: "Dio"} =
               (dune do
                  user = %{first_name: "Dio", last_name: "Brando"}
                  user.first_name
                end)
    end

    test "dynamic module names (authorized functions)" do
      assert %Success{value: %{}} =
               (dune do
                  module = Map
                  module.new()
                end)

      assert %Success{value: [%{}, %MapSet{}]} =
               (dune do
                  Enum.map([Map, MapSet], fn module -> module.new end)
                end)

      assert %Success{value: [%{}, %MapSet{}]} =
               (dune do
                  Enum.map([Map, MapSet], fn module -> module.new() end)
                end)
    end

    test "captures" do
      assert %Success{value: ["1", "2", "3"]} =
               (dune do
                  1..3 |> Enum.map(&inspect/1)
                end)

      assert %Success{value: [[0], [1, 0], [2, 0], [3, 0]]} =
               (dune do
                  0..30//10 |> Enum.map(&Integer.digits/1)
                end)

      assert %Success{value: 3.317550714905183e39} =
               (dune do
                  1..100//10 |> Enum.map(&:math.exp/1) |> Enum.sum()
                end)
    end

    test "sigils" do
      assert %Success{value: ~r/(a|b)?c/} = dune(do: ~r/(a|b)?c/)
      assert %Success{value: ~U[2021-05-20 01:02:03Z]} = dune(do: ~U[2021-05-20 01:02:03Z])
      assert %Success{value: [~c"foo", ~c"bar", ~c"baz"]} = dune(do: ~W[foo bar baz]c)

      assert %Success{value: [~c"foo", ~c"bar", ~c"baz"]} =
               dune(do: ~w[#{String.downcase("FOO")} bar baz]c)

      assert %Dune.Failure{
               message: "** (DuneRestrictedError) function sigil_W/2 is restricted",
               type: :restricted
             } = dune(do: ~W[foo bar baz]a)
    end

    test "block of code" do
      assert %Success{value: "quick-brown-fox-jumps-over-lazy-dog"} =
               (dune do
                  sentence = "the quick brown fox jumps over the lazy dog"
                  words = String.split(sentence)
                  filtered = Enum.reject(words, &(&1 == "the"))
                  Enum.join(filtered, "-")
                end)
    end

    test "pipe operator" do
      assert %Success{value: "quick-brown-fox-jumps-over-lazy-dog"} =
               (dune do
                  "the quick brown fox jumps over the lazy dog"
                  |> String.split()
                  |> Enum.reject(&(&1 == "the"))
                  |> Enum.join("-")
                end)
    end

    test "if block" do
      assert %Success{value: {:foo, 6}} =
               (dune do
                  x = 6

                  if x > 5 do
                    {:foo, x}
                  else
                    {:bar, x}
                  end
                end)
    end

    test "case block" do
      assert %Success{value: {:bar, 4}} =
               (dune do
                  case 4 do
                    x when x > 5 -> {:foo, x}
                    y -> {:bar, y}
                  end
                end)
    end

    test "for block" do
      assert %Success{value: [:b, :c]} =
               (dune do
                  for {x, y} <- [a: 1, b: 2, c: 3], y > 1, do: x
                end)
    end
  end

  describe "Dune restricted" do
    test "System calls" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function System.get_env/0 is restricted"
             } = dune(do: System.get_env())

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function System.get_env/1 is restricted"
             } = dune(do: System.get_env("TEST"))
    end

    test "Code calls" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Code.eval_string/1 is restricted"
             } = dune(do: Code.eval_string("IO.puts(:hello)"))
    end

    test "String/List restricted methods" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function String.to_atom/1 is restricted"
             } = dune(do: String.to_atom("foo"))

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function List.to_atom/1 is restricted"
             } = dune(do: List.to_atom(~c"foo"))

      assert %Failure{
               type: :restricted,
               message:
                 "** (DuneRestrictedError) function String.to_existing_atom/1 is restricted"
             } = dune(do: String.to_existing_atom("foo"))

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function List.to_existing_atom/1 is restricted"
             } = dune(do: List.to_existing_atom(~c"foo"))
    end

    test "atom interpolation" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function :erlang.binary_to_atom/2 is restricted"
             } = dune(do: :"#{1 + 1} is two")
    end

    test "Kernel apply/3" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Process.get/0 is restricted"
             } =
               (dune do
                  apply(Process, :get, [])
                end)

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function IO.puts/2 is restricted"
             } =
               (dune do
                  apply(IO, :puts, [:stderr, "Hello"])
                end)
    end

    test ". operator with variable modules" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function :erlang.yield/0 is restricted"
             } =
               (dune do
                  module = :erlang
                  module.yield
                end)

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function :erlang.processes/0 is restricted"
             } =
               (dune do
                  Enum.map([:erlang], fn module -> module.processes end)
                end)
    end

    test "capture operator" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Code.eval_string/1 is restricted"
             } = dune(do: f = &Code.eval_string/1)
    end

    test "Kernel 0-arity functions" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function binding/0 is restricted"
             } =
               (dune do
                  binding
                end)
    end

    test "erlang unsafe libs" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function :erlang.processes/0 is restricted"
             } = dune(do: :erlang.processes())

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function :erlang.get/0 is restricted"
             } = dune(do: :erlang.get())
    end

    test "nested restricted code" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Code.eval_string/1 is restricted"
             } =
               (dune do
                  f = fn -> Code.eval_string("IO.puts(:hello)") end
                end)
    end
  end

  describe "process restrictions" do
    test "execution timeout" do
      assert %Failure{type: :timeout, message: "Execution timeout - 100ms"} =
               dune(do: Process.sleep(101))
    end

    test "too many reductions" do
      assert %Failure{type: :reductions, message: "Execution stopped - reductions limit exceeded"} =
               dune(do: Enum.any?(1..1_000_000, &(&1 < 0)))
    end

    test "uses to much memory" do
      assert %Failure{type: :memory, message: "Execution stopped - memory limit exceeded"} =
               dune(do: List.duplicate(:foo, 100_000))
    end

    test "returns a big nested structure leveraging structural sharing" do
      # not sure if reductions or memory limit this first
      assert %Failure{message: "Execution stopped - " <> _} =
               dune(do: Enum.reduce(1..100, [:foo, :bar], fn _, acc -> [acc, acc] end))
    end

    test "returns a big binary" do
      assert %Failure{message: "Execution stopped - " <> _} =
               dune(do: String.duplicate("foo", 200_000))
    end
  end

  describe "error handling" do
    test "math error" do
      assert %Failure{
               type: :exception,
               message: "** (ArithmeticError) bad argument in arithmetic expression\n" <> rest
             } = dune(do: 42 / 0)

      assert rest =~ ":erlang./(42, 0)"
    end

    test "throw" do
      assert %Failure{type: :throw, message: "** (throw) :yo"} = dune(do: throw(:yo))
    end

    test "raise" do
      assert %Failure{type: :exception, message: "** (ArgumentError) kaboom!"} =
               (dune do
                  raise ArgumentError, "kaboom!"
                end)
    end

    test "actual UndefinedFunctionError" do
      assert %Failure{
               type: :exception,
               message: "** (UndefinedFunctionError) function Code.baz/0 is undefined or private"
             } = dune(do: Code.baz())

      assert %Failure{
               type: :exception,
               message:
                 "** (UndefinedFunctionError) function FooBar.baz/0 is undefined (module FooBar is not available)"
             } = dune(do: FooBar.baz())

      assert %Failure{
               type: :exception,
               message:
                 "** (UndefinedFunctionError) function :foo_bar.baz/0 is undefined (module :foo_bar is not available)"
             } = dune(do: :foo_bar.baz())
    end

    @tag :lts_only
    test "undefined variable" do
      capture_io(:stderr, fn ->
        # TODO better error messages
        assert %Failure{
                 type: :compile_error,
                 message:
                   "** (CompileError) nofile: cannot compile file (errors have been logged)",
                 stdio: "error: undefined variable \"y\"\n" <> _
               } = dune(do: y)

        assert %Failure{
                 type: :compile_error,
                 message:
                   "** (CompileError) nofile: cannot compile file (errors have been logged)",
                 stdio: "error: undefined variable \"x\"\n" <> _
               } = dune(do: if(x, do: x))
      end)
    end
  end
end
