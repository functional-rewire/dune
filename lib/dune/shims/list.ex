defmodule Dune.Shims.List do
  @moduledoc false

  def to_string(_env, list) when is_list(list) do
    do_to_string(list)
  end

  defp do_to_string(list) when is_list(list) do
    if Enum.any?(list, &is_list/1) do
      # eagerly convert lists to binary to prevent OOM on
      # structural sharing bombs
      Enum.map(list, &do_to_string/1)
    else
      list
    end
    |> List.to_string()
  end

  defp do_to_string(elem), do: elem
end
