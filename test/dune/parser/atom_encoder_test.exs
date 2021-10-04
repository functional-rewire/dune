defmodule Dune.Parser.AtomEncoderTest do
  use ExUnit.Case, async: true
  import Dune.Parser.AtomEncoder

  describe "categorize_atom_binary/1" do
    test "categorizes aliases cases" do
      assert :alias = categorize_atom_binary("Elixir")
      assert :alias = categorize_atom_binary("String")
      assert :alias = categorize_atom_binary("Foo.Bar")
    end

    test "categorizes valid public variable names" do
      assert :public_var = categorize_atom_binary("abc")
      assert :public_var = categorize_atom_binary("erlang")
      assert :public_var = categorize_atom_binary("あ")
    end

    test "categorizes valid private variable names" do
      assert :private_var = categorize_atom_binary("_")
      assert :private_var = categorize_atom_binary("_abc")
      assert :private_var = categorize_atom_binary("_あ")
    end

    test "categorizes other cases" do
      assert :other = categorize_atom_binary("")
      assert :other = categorize_atom_binary(" ")
      assert :other = categorize_atom_binary("a b")
      assert :other = categorize_atom_binary("A B")
      assert :other = categorize_atom_binary("Elixir. A")
      assert :other = categorize_atom_binary("Foo.Bar ")
      assert :other = categorize_atom_binary(" Foo.Bar")
    end
  end
end
