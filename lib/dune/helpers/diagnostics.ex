defmodule Dune.Helpers.Diagnostics do
  @moduledoc false

  # used for formatting errors and warnings consistently

  @type result_with_stdio :: %{stdio: binary()}

  @spec prepend_diagnostics(
          result_with_stdio(),
          [Code.diagnostic(:warning | :error)]
        ) :: result_with_stdio()
  def prepend_diagnostics(result, []), do: result

  def prepend_diagnostics(result, diagnostics) do
    %{result | stdio: format_diagnostics(diagnostics) <> "\n\n"}
  end

  @spec format_diagnostics([Code.diagnostic(:warning | :error)]) :: String.t()
  def format_diagnostics(diagnostics) do
    Enum.map_join(
      diagnostics,
      "\n",
      &"#{&1.severity}: #{&1.message}\n  #{&1.file}:#{format_pos(&1.position)}"
    )
  end

  defp format_pos(integer) when is_integer(integer), do: Integer.to_string(integer)
  defp format_pos({line, col}), do: [Integer.to_string(line), ?:, Integer.to_string(col)]

  @doc """
  A polyfill for `Code.with_diagnostics/1` for older versions of Elixir, which returns
  an empty list of diagnostics if not available.
  """

  # TODO remove then dropping support for 1.14
  if System.version() |> Version.compare("1.15.0") != :lt do
    defdelegate with_diagnostics_polyfill(fun), to: Code, as: :with_diagnostics
  else
    def with_diagnostics_polyfill(fun) do
      {fun.(), []}
    end
  end
end
