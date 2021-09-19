defmodule Dune.Allowlist.DefaultTest do
  use ExUnit.Case, async: true
  doctest Dune.Allowlist.Default
  alias Dune.Allowlist.Default

  describe "fun_status/3" do
    test "should not allow module_info/N" do
      assert :restricted = Default.fun_status(Float, :module_info, 0)
      assert :restricted = Default.fun_status(Float, :module_info, 1)
      assert :restricted = Default.fun_status(:math, :module_info, 0)
      assert :restricted = Default.fun_status(:math, :module_info, 1)
    end
  end
end
