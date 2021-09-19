defmodule Dune.AllowlistTest do
  use ExUnit.Case, async: true

  doctest Dune.Allowlist

  describe "use/2" do
    test "creates a new sandbox " do
      defmodule CustomAllowlist do
        use Dune.Allowlist

        allow Kernel, only: [:+, :*, :-, :/, :div, :rem]
        allow Integer, only: [:pow]
      end

      assert :allowed = CustomAllowlist.fun_status(Kernel, :+, 2)
      assert :restricted = CustomAllowlist.fun_status(Kernel, :<>, 2)
      assert :undefined_function = CustomAllowlist.fun_status(Kernel, :foo, 1)

      assert :allowed = CustomAllowlist.fun_status(Integer, :pow, 2)
      assert :restricted = CustomAllowlist.fun_status(Integer, :to_string, 1)
      assert :undefined_function = CustomAllowlist.fun_status(Integer, :foo, 1)

      assert :restricted = CustomAllowlist.fun_status(String, :upcase, 1)

      assert :undefined_module = CustomAllowlist.fun_status(Foo, :foo, 1)
    end

    test "extends an existing sandbox " do
      defmodule CustomModule do
        def authorized(i), do: i + 1
        def forbidden(i), do: i - 1
      end

      defmodule ExtendedAllowlist do
        use Dune.Allowlist, extend: Dune.Allowlist.Default

        allow CustomModule, only: [:authorized]
      end

      assert :allowed = ExtendedAllowlist.fun_status(String, :upcase, 1)
      assert :restricted = ExtendedAllowlist.fun_status(String, :to_atom, 1)

      assert :allowed = ExtendedAllowlist.fun_status(CustomModule, :authorized, 1)
      assert :restricted = ExtendedAllowlist.fun_status(CustomModule, :forbidden, 1)

      assert :undefined_module = ExtendedAllowlist.fun_status(Foo, :foo, 1)
    end
  end
end
