defmodule DuneStringToQuotedTest do
  use ExUnit.Case, async: true

  alias Dune.Success

  describe "Dune.string_to_quoted/2" do
    test "modules" do
      assert %Success{
               value: {:__aliases__, [line: 1], [:Dune_Atom_1__, :Dune_Atom_2__]},
               inspected: ~S"{:__aliases__, [line: 1], [:Foooo, :Barrr]}"
             } = Dune.string_to_quoted(~S(Foooo.Barrr))
    end
  end
end
