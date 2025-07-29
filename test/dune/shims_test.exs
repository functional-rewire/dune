defmodule Dune.ShimsTest do
  use ExUnit.Case, async: true

  alias Dune.Success
  alias Dune.Failure

  defmacrop sigil_E(call, _expr) do
    quote do
      Dune.eval_string(unquote(call), timeout: 100, inspect_sort_maps: true)
    end
  end

  describe "JSON" do
    @describetag :lts_only
    test "encode atoms" do
      assert %Success{value: ~S("json101"), inspected: ~S("\"json101\"")} =
               ~E'JSON.encode!(:json101)'

      assert %Success{value: ~S("json102"), inspected: ~S("\"json102\"")} =
               ~E'JSON.encode_to_iodata!(:json102) |> IO.iodata_to_binary()'

      assert %Success{
               value: ~S({"json201":["json202",123,"foo",null,true]}),
               inspected: ~S("{\"json201\":[\"json202\",123,\"foo\",null,true]}")
             } = ~E'JSON.encode!(%{json201: [:json202, 123, "foo", nil, true]})'
    end

    test "decode atoms" do
      assert %Success{value: "json301", inspected: ~S("json301")} =
               ~E'JSON.decode!("\"json301\"")'
    end
  end

  describe "iodata / chardata" do
    test "List.to_string" do
      assert %Success{value: <<1, 2, 3>>} = ~E'List.to_string([1, 2, 3])'
      assert %Success{value: <<1, 2, 3>>} = ~E'List.to_string([1, [[2], 3]])'
      assert %Success{value: "abc"} = ~E'List.to_string(["a", [["b"], "c"]])'

      assert %Failure{message: "** (ArgumentError) cannot convert the given list" <> _} =
               ~E'List.to_string([1, :foo])'
    end

    test "IO.chardata_to_string" do
      assert %Success{value: <<1, 2, 3>>} = ~E'IO.chardata_to_string([1, 2, 3])'
      assert %Success{value: <<1, 2, 3>>} = ~E'IO.chardata_to_string([1, [[2], 3]])'
      assert %Success{value: "abc"} = ~E'IO.chardata_to_string(["a", [["b"], "c"]])'

      assert %Failure{message: "** (ArgumentError) cannot convert the given list" <> _} =
               ~E'IO.chardata_to_string([1, :foo])'
    end
  end
end
