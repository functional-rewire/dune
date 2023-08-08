defmodule DuneStringTest do
  use ExUnit.Case, async: true

  alias Dune.{Success, Failure}

  defmacro sigil_E(call, _expr) do
    quote do
      Dune.eval_string(unquote(call), timeout: 100)
    end
  end

  describe "Dune authorized" do
    test "simple operations" do
      assert %Success{value: 5, inspected: ~S'5'} = ~E'2 + 3'
      assert %Success{value: 15, inspected: ~S'15'} = ~E'5 * 3'
      assert %Success{value: 0.5, inspected: ~S'0.5'} = ~E'1 / 2'
      assert %Success{value: [1, 2, 3, 4], inspected: ~S'[1, 2, 3, 4]'} = ~E'[1, 2] ++ [3, 4]'
      assert %Success{value: "abcd", inspected: ~S'"abcd"'} = ~E'"ab" <> "cd"'
      assert %Success{value: true, inspected: ~S'true'} = ~E'"abc!" =~ ~r/abc/'
    end

    test "basic Kernel functions" do
      assert %Success{value: 10, inspected: ~S'10'} = ~E'max(5, 10)'
      assert %Success{value: "foo", inspected: ~S'"foo"'} = ~E'to_string(:foo)'
      assert %Success{value: true, inspected: ~S'true'} = ~E'is_atom(:foo)'
    end

    test "Kernel guards" do
      assert %Success{value: false, inspected: ~S'false'} = ~E'is_binary(55)'
      assert %Success{value: true, inspected: ~S'true'} = ~E'is_number(55)'
    end

    test "basic String functions" do
      assert %Success{value: "JoJo", inspected: ~S'"JoJo"'} = ~E'String.replace("jojo", "j", "J")'
    end

    test "basic Map functions" do
      assert %Success{value: %{foo: 5}, inspected: ~S'%{foo: 5}'} = ~E'Map.put(%{}, :foo, 5)'
      assert %Success{value: %{}, inspected: ~S'%{}'} = ~E'Map.new()'
    end

    test "basic :math functions" do
      assert %Success{value: 3.0, inspected: ~S'3.0'} = ~E':math.log10(1000)'
      assert %Success{value: 3.141592653589793, inspected: ~S'3.141592653589793'} = ~E':math.pi()'
    end

    @tag :lts_only
    test "tuples" do
      assert %Success{value: {}, inspected: ~S'{}'} = ~E'{}'
      assert %Success{value: {:foo}, inspected: ~S'{:foo}'} = ~E'{:foo}'

      assert %Success{value: {"hello", ~c"world"}, inspected: ~S/{"hello", ~c"world"}/} =
               ~E/{"hello", 'world'}/

      assert %Success{value: {1, 2, 3}, inspected: ~S'{1, 2, 3}'} = ~E'{1, 2, 3}'
    end

    test "map operations" do
      assert %Success{value: %{a: :foo, b: 6}, inspected: ~S'%{a: :foo, b: 6}'} = ~E'
        map = %{a: 5, b: 6}
        %{map | a: :foo}
        '

      assert %Success{
               value: "Dio",
               inspected: ~S'"Dio"'
             } = ~E'
                  user = %{first_name: "Dio", last_name: "Brando"}
                  user.first_name
                '
    end

    test "dynamic module names (authorized functions)" do
      assert %Success{value: %{}, inspected: ~S'%{}'} = ~E'module = Map; module.new()'

      assert %Success{value: [%{}], inspected: ~S'[%{}]'} =
               ~E'Enum.map([Map], fn module -> module.new end)'

      assert %Success{value: [%{}], inspected: ~S'[%{}]'} =
               ~E'Enum.map([Map], fn module -> module.new() end)'

      assert %Success{value: 3, inspected: ~S'3'} = ~E'apply(List, :last, [[1, 2, 3]])'
    end

    test "captures" do
      assert %Success{value: 33, inspected: ~S'33'} = ~E'f = &+/2; f.(11, 22)'

      assert %Success{value: 35, inspected: ~S'35'} = ~E'f = & &1*&2; f.(5, 7)'

      assert %Success{value: 1.5, inspected: ~S'1.5'} = ~E'f = & &1/&2; 3 |> f.(2)'

      assert %Success{value: 20, inspected: ~S'20'} = ~E'apply(& &1 * 2, [10])'

      assert %Success{value: ["1", "2", "3"], inspected: ~S'["1", "2", "3"]'} =
               ~E'1..3 |> Enum.map(&inspect/1)'

      assert %Success{
               value: [[0], [1, 0], [2, 0], [3, 0]],
               inspected: ~S'[[0], [1, 0], [2, 0], [3, 0]]'
             } = ~E'0..30//10 |> Enum.map(&Integer.digits/1)'

      assert %Success{value: 3.317550714905183e39, inspected: ~S'3.317550714905183e39'} =
               ~E'1..100//10 |> Enum.map(&:math.exp/1) |> Enum.sum()'
    end

    test "anonymous functions" do
      assert %Success{value: 0, inspected: ~S'0'} = ~E'f = fn -> _x = 0 end; f.()'
      assert %Success{value: 0, inspected: ~S'0'} = ~E'(fn -> _x = 0 end).()'
      assert %Success{value: 3, inspected: ~S'3'} = ~E'2 |> (fn x -> x + 1 end).()'
      assert %Success{value: -4, inspected: ~S'-4'} = ~E'(&(&2 - &1)).(7, 3)'
      assert %Success{value: -4, inspected: ~S'-4'} = ~E'(& &2 - &1).(7, 3)'
      assert %Success{value: 3, inspected: ~S'3'} = ~E'2 |> (& &1 + 1).()'
      assert %Success{value: 0.2, inspected: ~S'0.2'} = ~E'(& &2 / &1).(10, 2)'
    end

    @tag :lts_only
    test "sigils" do
      assert %Success{value: ~r/(a|b)?c/, inspected: ~S'~r/(a|b)?c/'} = ~E'~r/(a|b)?c/'

      assert %Success{value: ~U[2021-05-20 01:02:03Z], inspected: ~S'~U[2021-05-20 01:02:03Z]'} =
               ~E'~U[2021-05-20 01:02:03Z]'

      assert %Success{
               value: [~c"foo", ~c"bar", ~c"baz"],
               inspected: ~S'[~c"foo", ~c"bar", ~c"baz"]'
             } = ~E'~W[foo bar baz]c'

      assert %Success{
               value: [~c"foo", ~c"bar", ~c"baz"],
               inspected: ~S'[~c"foo", ~c"bar", ~c"baz"]'
             } = ~E'~w[#{String.downcase("FOO")} bar baz]c'

      assert %Dune.Failure{
               message: "** (DuneRestrictedError) function sigil_W/2 is restricted",
               type: :restricted
             } = ~E'~W[foo bar baz]a'

      assert %Dune.Failure{
               message: "** (DuneRestrictedError) function sigil_w/2 is restricted",
               type: :restricted
             } = ~E'~w[#{String.downcase("FOO")} bar baz]a'
    end

    test "binary comprehensions" do
      assert %Success{
               value: [{213, 45, 132}, {64, 76, 32}],
               inspected: "[{213, 45, 132}, {64, 76, 32}]"
             } = ~E'''
             pixels = <<213, 45, 132, 64, 76, 32>>
             for <<r::8, g::8, b::8 <- pixels>>, do: {r, g, b}
             '''
    end

    test "block of code" do
      assert %Success{
               value: "quick-brown-fox-jumps-over-lazy-dog",
               inspected: ~S'"quick-brown-fox-jumps-over-lazy-dog"'
             } = ~E'
                  sentence = "the quick brown fox jumps over the lazy dog"
                  words = String.split(sentence)
                  filtered = Enum.reject(words, &(&1 == "the"))
                  Enum.join(filtered, "-")
                '
    end

    test "pipe operator" do
      assert %Success{
               value: "quick-brown-fox-jumps-over-lazy-dog",
               inspected: ~S'"quick-brown-fox-jumps-over-lazy-dog"'
             } = ~E'
                  "the quick brown fox jumps over the lazy dog"
                  |> String.split()
                  |> Enum.reject(&(&1 == "the"))
                  |> Enum.join("-")
                '

      assert %Success{value: ":foo", inspected: ~S'":foo"'} = ~E':foo |> inspect()'
    end

    test "atoms" do
      assert %Success{value: "foo51", inspected: ~s'"foo51"'} = ~E'to_string(:foo51)'

      assert %Success{value: "foo52", inspected: ~s'"foo52"'} = ~E'Atom.to_string(:foo52)'

      assert %Success{value: "foo53", inspected: ~s'"foo53"'} = ~E'Enum.join([:foo53])'

      assert %Success{value: "boo57", inspected: ~s'"boo57"'} =
               ~E':foo57 |> to_string() |> String.replace("f", "b")'

      assert %Success{value: "Hello boo58", inspected: ~s'"Hello boo58"'} =
               ~E'"Hello #{:foo58}" |> String.replace("f", "b")'

      assert %Success{value: :Dune_Atom_1__, inspected: ~s':Foo12'} = ~E':Foo12'
      assert %Success{value: Dune_Module_1__, inspected: ~s'Foo13'} = ~E'Foo13'

      assert %Success{value: "Foo14", inspected: ~s'"Foo14"'} = ~E'Atom.to_string(:Foo14)'

      assert %Success{value: "Elixir.Foo15", inspected: ~s("Elixir.Foo15")} =
               ~E'Atom.to_string(Foo15)'

      assert %Success{value: ":Foo16", inspected: ~s'":Foo16"'} = ~E'inspect(:Foo16)'

      assert %Success{value: "Foo17", inspected: ~s'"Foo17"'} = ~E'inspect(Foo17)'

      assert %Success{value: "Elixir.Foo.Bar33", inspected: ~s("Elixir.Foo.Bar33")} =
               ~E'Atom.to_string(Foo.Bar33)'

      assert %Success{
               value: [
                 Dune_Module_1__,
                 {:a__Dune_atom_2__, :Dune_Atom_1__},
                 [a__Dune_atom_2__: 15, Dune_Atom_1__: 6, __Dune_atom_3__: 33]
               ],
               inspected: ~s([Foo91, {:foo91, :Foo91}, [foo91: 15, Foo91: 6, _foo92: 33]])
             } = ~E'[Foo91, {:foo91, :Foo91}, [foo91: 15, Foo91: 6, _foo92: 33]]'
    end

    @tag :lts_only
    test "atoms to charlist" do
      assert %Success{value: ~c"Hello foo59", inspected: ~s'~c"Hello foo59"'} =
               ~E'~c"Hello #{:foo59}"'

      assert %Success{value: ~c"Elixir.Foo15", inspected: ~s(~c"Elixir.Foo15")} =
               ~E'Atom.to_charlist(Foo15)'
    end

    test "atoms (prefixed by Elixir)" do
      assert %Success{value: Elixir, inspected: ~s'Elixir'} = ~E'Elixir'

      assert %Success{value: Dune_Module_1__, inspected: ~s'Foo13'} = ~E'Elixir.Foo13'
      assert %Success{value: Dune_Module_1__, inspected: ~s'Foo13'} = ~E':"Elixir.Foo13"'

      assert %Success{value: true, inspected: ~s'true'} = ~E'Elixir.Foo13 == Foo13'
      assert %Success{value: true, inspected: ~s'true'} = ~E':"Elixir.Foo13" == Foo13'

      assert %Success{value: true, inspected: ~s'true'} = ~E'Elixir.Foo13.Foo13 == Foo13.Foo13'
      assert %Success{value: true, inspected: ~s'true'} = ~E':"Elixir.Foo13.Foo13" == Foo13.Foo13'

      assert %Success{value: String, inspected: ~s'String'} = ~E':"Elixir.String"'

      assert %Success{value: Dune_Module_1__, inspected: ~s'Elixir.Elixir'} = ~E'Elixir.Elixir'
      assert %Success{value: Dune_Module_1__, inspected: ~s'Elixir.Elixir'} = ~E':"Elixir.Elixir"'
    end

    test "atoms (wrapped with quotes)" do
      assert %Success{value: :__Dune_atom_1__, inspected: ~s':" "'} = ~E':" "'
      assert %Success{value: :__Dune_atom_1__, inspected: ~s':"foo/bar"'} = ~E':"foo/bar"'

      assert %Success{value: " ", inspected: ~s'" "'} = ~E'to_string :" "'
      assert %Success{value: "foo/bar", inspected: ~s'"foo/bar"'} = ~E'to_string :"foo/bar"'

      assert %Success{
               value: [
                 __Dune_atom_1__: {:__Dune_atom_2__, :__Dune_atom_3__},
                 __Dune_atom_4__: %{__Dune_atom_5__: :__Dune_atom_6__, a__Dune_atom_7__: 6}
               ],
               inspected: ~s([" ": {:"\t", :" A"}, "ab cd": %{"foo+91": :"15", abc: 6}])
             } = ~E([" ": {:"\t", :" A"}, "ab cd": %{"foo+91": :'15', abc: 6}])
    end

    test "function and atom parameters" do
      assert ":digits" = ~E':digits'.value |> inspect()
      assert ":turkic" = ~E':turkic'.value |> inspect()
    end

    test "stdio capture" do
      assert %Success{value: :ok, inspected: ~s(:ok), stdio: "yo!\n"} = ~E'IO.puts("yo!")'
      assert %Success{value: :ok, inspected: ~s(:ok), stdio: "foo987\n"} = ~E'IO.puts(:foo987)'

      assert %Success{value: :ok, inspected: ~s(:ok), stdio: "hello world!\n"} =
               ~E'io = IO; io.puts(["hello", ?\s, "world", ?!])'

      assert %Success{value: :ok, inspected: ~s(:ok), stdio: "1\n2\n3\n"} =
               ~E'Enum.each(1..3, &IO.puts/1)'

      assert %Success{value: :a__Dune_atom_1__, inspected: ~s(:foo912), stdio: ":foo912\n"} =
               ~E'IO.inspect(:foo912)'

      assert %Success{
               value: %{a__Dune_atom_1__: 581},
               inspected: ~s(%{foo9101: 581}),
               stdio: "bar777: %{foo9101: 581}\n"
             } = ~E'%{foo9101: 581} |> IO.inspect(label: :bar777)'

      assert %Success{
               value: :ok,
               inspected: ":ok",
               stdio: ":foo9321\nfoo9321\n"
             } = ~E'io = IO; io.puts(io.inspect(:foo9321))'
    end

    test "pretty option" do
      raw_string =
        ~S'{"This line is really long, maybe we should break", [%{bar: 1, baz: 2}, %{bar: 55}]}'

      with_break =
        ~s'{"This line is really long, maybe we should break",\n [%{bar: 1, baz: 2}, %{bar: 55}]}'

      assert %Success{inspected: ^raw_string} = Dune.eval_string(raw_string)
      assert %Success{inspected: ^with_break} = Dune.eval_string(raw_string, pretty: true)
    end
  end

  describe "Dune restricted" do
    test "System calls" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function System.get_env/0 is restricted"
             } = ~E'System.get_env()'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function System.get_env/1 is restricted"
             } = ~E'System.get_env("TEST")'
    end

    test "Code calls" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Code.eval_string/1 is restricted"
             } = ~E'Code.eval_string("IO.puts(:hello)")'
    end

    test "String/List restricted methods" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function String.to_atom/1 is restricted"
             } = ~E'String.to_atom("foo")'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function List.to_atom/1 is restricted"
             } = ~E/List.to_atom('foo')/
    end

    test "atom interpolation" do
      assert %Failure{
               type: :restricted,
               message:
                 "** (DuneRestrictedError) function :erlang.binary_to_existing_atom/2 is restricted"
             } = ~E':"#{1 + 1} is two"'
    end

    test "Kernel apply/3" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Process.get/0 is restricted"
             } = ~E'apply(Process, :get, [])'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function IO.puts/2 is restricted"
             } = ~E'apply(IO, :puts, [:stderr, "Hello"])'
    end

    test ". operator with variable modules" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function :erlang.yield/0 is restricted"
             } = ~E'
                  module = :erlang
                  module.yield
                '

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function :erlang.processes/0 is restricted"
             } = ~E'
                  Enum.map([:erlang], fn module -> module.processes end)
                '
    end

    test ". operator as key access" do
      assert %Success{value: 100, inspected: ~S'100'} =
               ~E'users = [john: %{age: 100}]; users[:john].age'
    end

    test ". operator various failures" do
      assert %Failure{
               type: :exception,
               message:
                 "** (UndefinedFunctionError) function :foo.bar/0 is undefined (module :foo is not available)"
             } = ~E'module = :foo; module.bar()'

      assert %Failure{
               type: :exception,
               message: "** (UndefinedFunctionError) function List.bar/0 is undefined or private"
             } = ~E'module = List; module.bar()'

      assert %Failure{
               type: :exception,
               message: "** (KeyError) key :job not found in: %{age: 100}\n" <> _
             } = ~E'users = [john: %{age: 100}]; users[:john].job'

      assert %Failure{
               type: :exception,
               message:
                 "** (UndefinedFunctionError) function Foo1234.bar567/0 is undefined (module Foo1234 is not available)"
             } = ~E'Foo1234.bar567.baz890'
    end

    test "pipe operator" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Code.eval_string/1 is restricted"
             } = ~E'":foo" |> Code.eval_string()'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Code.eval_string/1 is restricted"
             } = ~E'code = Code; "1 + 1" |> code.eval_string()'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Code.eval_string/1 is restricted"
             } = ~E'code = Code; "1 + 1" |> code.eval_string'
    end

    test "capture operator" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Code.eval_string/1 is restricted"
             } = ~E'f = &Code.eval_string/1'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Code.eval_string/1 is restricted"
             } = ~E'f = &Code.eval_string(&1)'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Code.eval_string/1 is restricted"
             } = ~E'(&Code.eval_string/1).(":pawned!")'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Code.eval_string/1 is restricted"
             } = ~E'(&Code.eval_string(&1)).(":pawned!")'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Code.eval_string/1 is restricted"
             } = ~E'":pawned!" |> (&Code.eval_string/1).()'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Code.eval_string/1 is restricted"
             } = ~E'":pawned!" |> (&Code.eval_string(&1)).()'
    end

    test "Kernel 0-arity functions" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function binding/0 is restricted"
             } = ~E'binding'
    end

    test "erlang unsafe libs" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function :erlang.processes/0 is restricted"
             } = ~E':erlang.processes()'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function :erlang.get/0 is restricted"
             } = ~E':erlang.get()'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function :erlang.process_info/1 is restricted"
             } = ~E':erlang.process_info(self)'
    end

    test "nested restricted code" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function Code.eval_string/1 is restricted"
             } = ~E'f = fn -> Code.eval_string("IO.puts(:hello)") end'
    end

    test "partially restricted shims" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function IO.puts/2 is restricted"
             } = ~E'IO.puts(:stderr, "foo")'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function IO.puts/2 is restricted"
             } = ~E':stderr |> IO.puts("foo")'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function IO.inspect/3 is restricted"
             } = ~E'IO.inspect(:stderr, "foo", [])'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function IO.inspect/3 is restricted"
             } = ~E'io = IO; io.inspect(:stderr, "foo", [])'
    end

    test "forbidden atoms" do
      assert %Failure{
               type: :restricted,
               message: "Atoms containing `Dune` are restricted for safety: Dune"
             } = ~E'Dune'

      assert %Failure{
               type: :restricted,
               message: "Atoms containing `Dune` are restricted for safety: Dune"
             } = ~E'Dune.Foo'

      assert %Failure{
               type: :restricted,
               message: "Atoms containing `Dune` are restricted for safety: Dune"
             } = ~E':Dune'

      assert %Failure{
               type: :restricted,
               message: "Atoms containing `Dune` are restricted for safety: __Dune__"
             } = ~E':__Dune__'
    end

    test "forbidden use" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function use/1 is restricted"
             } = ~E'use GenServer'
    end

    test "forbidden import/requires" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function import/1 is restricted"
             } = ~E'import Logger'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function import/2 is restricted"
             } = ~E'import Logger, only: [info: 2]'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function require/1 is restricted"
             } = ~E'require Logger'
    end

    test "forbidden alias" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function alias/1 is restricted"
             } = ~E'alias Task.Supervised'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function alias/2 is restricted"
             } = ~E'alias Process, as: P; P.get'
    end

    test "forbidden quote/unquote" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function quote/1 is restricted"
             } = ~E'quote do: 1 + 1'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function quote/1 is restricted"
             } = ~E'quote do: unquote(a)'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function unquote/1 is restricted"
             } = ~E'unquote(10)'
    end

    test "forbidden receive" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function receive/1 is restricted"
             } = ~E'''
             receive do
               {:ok, foo} -> foo
             end
             '''
    end

    test "forbidden __ENV__" do
      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function __ENV__/0 is restricted"
             } = ~E'__ENV__'

      assert %Failure{
               type: :restricted,
               message: "** (DuneRestrictedError) function __ENV__/0 is restricted"
             } = ~E'__ENV__.requires'
    end
  end

  describe "process restrictions" do
    test "execution timeout" do
      assert %Failure{type: :timeout, message: "Execution timeout - 100ms"} =
               ~E'Process.sleep(101)'
    end

    test "too many reductions" do
      assert %Failure{type: :reductions, message: "Execution stopped - reductions limit exceeded"} =
               ~E'Enum.any?(1..1_000_000, &(&1 < 0))'
    end

    test "uses to much memory" do
      assert %Failure{type: :memory, message: "Execution stopped - memory limit exceeded"} =
               ~E'List.duplicate(:foo, 100_000)'
    end

    test "returns a big nested structure leveraging structural sharing" do
      # not sure if reductions or memory limit this first
      assert %Failure{message: "Execution stopped - " <> _} =
               ~E'Enum.reduce(1..100, [:foo, :bar], fn _, acc -> [acc, acc] end)'
    end

    test "returns a big binary" do
      assert %Failure{message: "Execution stopped - " <> _} = ~E'String.duplicate("foo", 200_000)'
    end
  end

  describe "error handling" do
    test "math error" do
      assert %Failure{
               type: :exception,
               message: "** (ArithmeticError) bad argument in arithmetic expression\n" <> rest
             } = ~E'42 / 0'

      assert rest =~ ":erlang./(42, 0)"
    end

    test "throw" do
      assert %Failure{type: :throw, message: "** (throw) :yo"} = ~E'throw(:yo)'
    end

    test "raise" do
      assert %Failure{type: :exception, message: "** (ArgumentError) kaboom!"} =
               ~E'raise ArgumentError, "kaboom!"'
    end

    test "actual UndefinedFunctionError" do
      assert %Failure{
               type: :exception,
               message: "** (UndefinedFunctionError) function Code.baz/0 is undefined or private"
             } = ~E'Code.baz()'

      assert %Failure{
               type: :exception,
               message:
                 "** (UndefinedFunctionError) function FooBar.baz/0 is undefined (module FooBar is not available)"
             } = ~E'FooBar.baz()'

      assert %Failure{
               type: :exception,
               message:
                 "** (UndefinedFunctionError) function :foo_bar.baz/0 is undefined (module :foo_bar is not available)"
             } = ~E':foo_bar.baz()'
    end

    test "syntax error" do
      assert %Failure{
               type: :parsing,
               message: "missing terminator: ) (for \"(\" starting at line 1)"
             } = ~E'foo('

      assert %Failure{
               type: :parsing,
               message: "missing terminator: } (for \"{\" starting at line 1)"
             } = ~E'{'

      assert %Failure{
               type: :parsing,
               message: "unexpected reserved word: do. In case you wanted to write " <> _
             } = ~E'if true, do'

      # TODO improve message
      assert %Failure{type: :parsing, message: "syntax error before: "} = ~E'%'

      assert %Failure{type: :parsing, message: "syntax error before: foo120987"} =
               ~E'<<>>foo120987'
    end

    test "max length" do
      assert %Failure{
               type: :parsing,
               message: "max code length exceeded: 26 > 10"
             } = Dune.eval_string("exceeeds_max_length = true", max_length: 10)
    end

    test "atom pool" do
      assert %Failure{
               type: :parsing,
               message: "atom_pool_size exceeded, failed to parse atom: bar1462"
             } = Dune.eval_string("{foo5345, bar1462} = {9, 10}", atom_pool_size: 4)
    end

    test "invalid pipe" do
      assert %Failure{
               type: :exception,
               message: "** (ArgumentError) cannot pipe 1 into 2, can only pipe into " <> _
             } = ~E'1 |> 2'

      assert %Failure{
               type: :exception,
               message: "** (UndefinedFunctionError) function b/1 is undefined or private"
             } = ~E'a |> b'
    end

    @tag :lts_only
    test "compile error" do
      # TODO capture diagnostics
      assert %Failure{
               type: :exception,
               message:
                 "** (CompileError) nofile: cannot compile file (errors have been logged)" <>
                   _
             } = ~E'
                case 1 do
                end
              '
    end

    test "def/defp outside of module" do
      assert %Failure{
               type: :exception,
               message: "** (ArgumentError) cannot invoke def/2 inside function/macro"
             } = ~E'def foo(x), do: x + x'

      assert %Failure{
               type: :exception,
               message: "** (ArgumentError) cannot invoke defp/2 inside function/macro"
             } = ~E'defp foo(x), do: x + x'

      assert %Failure{
               type: :exception,
               message: "** (ArgumentError) cannot invoke def/2 inside function/macro"
             } = ~E'&def/2'
    end
  end
end
