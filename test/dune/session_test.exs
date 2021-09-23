defmodule Dune.SessionTest do
  use ExUnit.Case
  doctest Dune.Session

  alias Dune.{Session, Success, Failure}

  @module_code """
  defmodule MySum do
    def sum(xs), do: sum(xs, 0)
    defp sum([], acc), do: acc
    defp sum([x | xs], acc) do
      sum(xs, acc + x)
    end
  end
  """

  describe "eval_string/3" do
    test "keeps variable bindings" do
      session =
        Session.new()
        |> Session.eval_string("abcd = 5")
        |> Session.eval_string("abcd")

      assert %Session{
               last_result: %Success{inspected: "5"},
               bindings: [a__Dune_atom_1__: 5]
             } = session
    end

    test "ignores failed steps" do
      session =
        Session.new()
        |> Session.eval_string("abcd = 5")
        |> Session.eval_string("abcd = 1 / 0")
        |> Session.eval_string("abcd")

      assert %Session{
               last_result: %Success{inspected: "5"},
               bindings: [a__Dune_atom_1__: 5]
             } = session
    end

    test "keeps variable bindings on errors" do
      session =
        Session.new()
        |> Session.eval_string("abcd = 5")
        |> Session.eval_string("abcd / 0")

      assert %Session{
               last_result: %Failure{
                 message: "** (ArithmeticError) bad argument in arithmetic expression" <> _
               },
               bindings: [a__Dune_atom_1__: 5]
             } = session
    end

    test "keeps the atom mapping" do
      session =
        Session.new()
        |> Session.eval_string("abcd = :abcd")
        |> Session.eval_string("efgh = :efgh")
        |> Session.eval_string("[abcd, efgh]")

      assert %Session{
               last_result: %Success{inspected: "[:abcd, :efgh]"},
               bindings: [
                 a__Dune_atom_2__: :a__Dune_atom_2__,
                 a__Dune_atom_1__: :a__Dune_atom_1__
               ]
             } = session
    end

    test "keeps the module mapping" do
      session =
        Session.new()
        |> Session.eval_string("acbd = [Aa]")
        |> Session.eval_string("acbd = acbd ++ [Bb]")
        |> Session.eval_string("acbd = acbd ++ [Aa.Bb]")
        |> Session.eval_string("acbd ++ [Cc.Dd]")

      assert %Session{
               last_result: %Success{inspected: "[Aa, Bb, Aa.Bb, Cc.Dd]"},
               bindings: [a__Dune_atom_1__: [Dune_Module_1__, Dune_Module_2__, Dune_Module_3__]]
             } = session
    end

    test "handles modules" do
      session =
        Session.new()
        |> Session.eval_string(@module_code)
        |> Session.eval_string("MySum.sum([1, 2, 100])")

      assert %Session{
               last_result: %Success{inspected: "103"},
               bindings: []
             } = session
    end

    test "does not break due to Elixir single atom bug" do
      session = Session.new() |> Session.eval_string(":foo")

      assert %Session{
               last_result: %Success{inspected: ":foo"},
               bindings: []
             } = session
    end
  end
end
