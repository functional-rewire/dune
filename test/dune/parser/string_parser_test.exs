defmodule Dune.Parser.StringParserTest do
  use ExUnit.Case, async: true

  alias Dune.{AtomMapping, Opts}
  alias Dune.Parser.{StringParser, UnsafeAst}

  describe "parse_string/2" do
    test "existing atoms" do
      assert %UnsafeAst{ast: nil, atom_mapping: AtomMapping.new()} ==
               StringParser.parse_string("nil", %Opts{}, nil)

      assert %UnsafeAst{ast: true, atom_mapping: AtomMapping.new()} ==
               StringParser.parse_string("true", %Opts{}, nil)

      assert %UnsafeAst{ast: :atom, atom_mapping: AtomMapping.new()} ==
               StringParser.parse_string(":atom", %Opts{}, nil)

      assert %UnsafeAst{ast: :Atom, atom_mapping: AtomMapping.new()} ==
               StringParser.parse_string(":Atom", %Opts{}, nil)
    end

    test "existing modules" do
      assert %UnsafeAst{
               ast: {:__aliases__, [line: 1], [:Module]},
               atom_mapping: AtomMapping.new()
             } == StringParser.parse_string("Module", %Opts{}, nil)

      assert %UnsafeAst{
               ast: {:__aliases__, [line: 1], [:Date, :Range]},
               atom_mapping: AtomMapping.new()
             } == StringParser.parse_string("Date.Range", %Opts{}, nil)
    end

    test "non-existing atoms" do
      assert %UnsafeAst{
               ast: :a__Dune_atom_1__,
               atom_mapping: %AtomMapping{
                 atoms: %{a__Dune_atom_1__: "my_atom"},
                 modules: %{},
                 extra_info: %{}
               }
             } == StringParser.parse_string(":my_atom", %Opts{}, nil)

      assert %UnsafeAst{
               ast: :__Dune_atom_1__,
               atom_mapping: %AtomMapping{
                 atoms: %{__Dune_atom_1__: "_my_atom"},
                 modules: %{},
                 extra_info: %{}
               }
             } == StringParser.parse_string(":_my_atom", %Opts{}, nil)

      assert %UnsafeAst{
               ast: :Dune_Atom_1__,
               atom_mapping: %AtomMapping{
                 atoms: %{Dune_Atom_1__: "MyAtom"},
                 modules: %{},
                 extra_info: %{}
               }
             } == StringParser.parse_string(":MyAtom", %Opts{}, nil)
    end

    test "non-existing modules" do
      assert %UnsafeAst{
               ast: {:__aliases__, [line: 1], [:Dune_Module_1__]},
               atom_mapping: %AtomMapping{
                 atoms: %{Dune_Atom_1__: "MyModule"},
                 modules: %{Dune_Module_1__ => "MyModule"},
                 extra_info: %{}
               }
             } == StringParser.parse_string("MyModule", %Opts{}, nil)

      assert %UnsafeAst{
               ast: {:__aliases__, [line: 1], [:Dune_Module_1__]},
               atom_mapping: %AtomMapping{
                 atoms: %{Dune_Atom_1__: "My", Dune_Atom_2__: "AwesomeModule"},
                 modules: %{Dune_Module_1__ => "My.AwesomeModule"},
                 extra_info: %{}
               }
             } == StringParser.parse_string("My.AwesomeModule", %Opts{}, nil)

      assert %UnsafeAst{
               ast: {:__aliases__, [line: 1], [:Dune_Module_1__]},
               atom_mapping: %AtomMapping{
                 atoms: %{Dune_Atom_1__: "My"},
                 modules: %{Dune_Module_1__ => "My.Module"},
                 extra_info: %{}
               }
             } == StringParser.parse_string("My.Module", %Opts{}, nil)
    end

    test ~S[non-existing "wrapped" atoms (with whitespace)] do
      assert %UnsafeAst{
               ast: :__Dune_atom_1__,
               atom_mapping: %AtomMapping{
                 atoms: %{__Dune_atom_1__: " "},
                 modules: %{},
                 extra_info: %{__Dune_atom_1__: :wrapped}
               }
             } == StringParser.parse_string(~S(:" "), %Opts{}, nil)

      assert %UnsafeAst{
               ast: :__Dune_atom_1__,
               atom_mapping: %AtomMapping{
                 atoms: %{__Dune_atom_1__: "my atom"},
                 modules: %{},
                 extra_info: %{__Dune_atom_1__: :wrapped}
               }
             } == StringParser.parse_string(~S(:"my atom"), %Opts{}, nil)
    end
  end
end
