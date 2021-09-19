defmodule Dune.Parser.Debug do
  @moduledoc false

  def io_debug(ast) do
    debug(ast) |> IO.puts()
    ast
  end

  def debug(%{ast: ast}) when is_tuple(ast) do
    ast_to_string(ast)
  end

  def debug(ast) when is_tuple(ast) do
    ast_to_string(ast)
  end

  defp ast_to_string({:__block__, _, list}) do
    Enum.map_join(list, "\n", &Macro.to_string/1)
  end

  defp ast_to_string(ast) do
    Macro.to_string(ast)
  end
end
