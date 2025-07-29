defmodule Dune.AssertionHelper do
  alias Dune.Failure

  defmacro test_execution_stops(test_name, do: expr) do
    quote do
      test unquote(test_name) do
        # not sure if reductions or memory limit this first
        assert %Failure{message: "Execution stopped - " <> _} =
                 Dune.eval_quoted(unquote(Macro.escape(expr)), timeout: 100)
      end
    end
  end
end

defmodule Dune.OOMSafetyTest do
  # Safety integration tests for "structural-sharing bombs" edge cases
  # that would cause BIFs to hang and use enormous amounts of memory

  use ExUnit.Case, async: true

  import Dune.AssertionHelper

  test_execution_stops "List.duplicate" do
    List.duplicate(:foo, 200_000)
  end

  # TODO figure out why this fails since Elixir 1.18
  @tag :skip
  test_execution_stops "String.duplicate" do
    String.duplicate("foo", 200_000)
  end

  describe "structural sharing bombs" do
    test_execution_stops "returning value directly" do
      Enum.reduce(1..100, ["foo", "bar"], fn _, acc -> [acc, acc] end)
    end

    test_execution_stops "inspect" do
      Enum.reduce(1..100, ["foo", "bar"], fn _, acc -> [acc, acc] end) |> inspect()
    end

    test_execution_stops "string interpolation" do
      bomb = Enum.reduce(1..100, ["foo", "bar"], fn _, acc -> [acc, acc] end)
      "#{bomb}!"
    end

    test_execution_stops "to_string" do
      Enum.reduce(1..100, ["foo", "bar"], fn _, acc -> [acc, acc] end) |> to_string()
    end

    test_execution_stops "List.to_string" do
      Enum.reduce(1..100, ["foo", "bar"], fn _, acc -> [acc, acc] end) |> List.to_string()
    end

    test_execution_stops "IO.iodata_to_binary" do
      Enum.reduce(1..100, ["foo", "bar"], fn _, acc -> [acc, acc] end) |> IO.iodata_to_binary()
    end

    test_execution_stops "IO.chardata_to_string" do
      Enum.reduce(1..100, ["foo", "bar"], fn _, acc -> [acc, acc] end) |> IO.chardata_to_string()
    end

    test_execution_stops "Enum.join" do
      Enum.reduce(1..100, ["foo", "bar"], fn _, acc -> [acc, acc] end) |> Enum.join()
    end

    @tag :lts_only
    test_execution_stops "JSON encode key" do
      bomb = Enum.reduce(1..100, ["foo", "bar"], fn _, acc -> [acc, acc] end)
      JSON.encode!(%{bomb => 123})
    end
  end
end
