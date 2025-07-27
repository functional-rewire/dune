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

    @tag :lts_only
    test "captures tokenizer warnings" do
      assert %Success{
               value: ~c"single quotes",
               inspected: ~S(~c"single quotes"),
               stdio: stdio
             } = Dune.string_to_quoted(~S('single quotes'))

      assert stdio =~ "warning: using single-quoted strings to represent charlists is deprecated."
    end
  end
end
