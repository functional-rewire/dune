defmodule Dune.ShimsTest do
  use ExUnit.Case, async: true

  alias Dune.Success

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
end
