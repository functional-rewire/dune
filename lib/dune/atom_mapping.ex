defmodule Dune.AtomMapping do
  @moduledoc false

  alias Dune.{Success, Failure}

  @type substitute_atom :: atom
  @type original_string :: String.t()
  @type sub_mapping :: %{optional(substitute_atom) => original_string}
  @type extra_info :: %{optional(substitute_atom) => :wrapped}

  @typedoc """
  Should be considered opaque
  """
  @type t :: %__MODULE__{atoms: sub_mapping, modules: sub_mapping, extra_info: extra_info}
  @enforce_keys [:atoms, :modules, :extra_info]
  defstruct @enforce_keys

  @spec new :: t()
  def new do
    %__MODULE__{atoms: %{}, modules: %{}, extra_info: %{}}
  end

  @spec from_atoms([{substitute_atom, original_string}], [{substitute_atom, :wrapped}]) :: t
  def from_atoms(list, extra_info) when is_list(list) do
    atoms = build_mapping(list)
    extra_info = Map.new(extra_info)
    %__MODULE__{atoms: atoms, modules: %{}, extra_info: extra_info}
  end

  @spec add_modules(t, [{substitute_atom, original_string}]) :: t
  def add_modules(mapping = %__MODULE__{}, list) do
    %{mapping | modules: build_mapping(list)}
  end

  defp build_mapping(list) do
    Map.new(list, fn {substitute_atom, original_string}
                     when is_atom(substitute_atom) and is_binary(original_string) ->
      {substitute_atom, original_string}
    end)
  end

  @spec to_string(t, atom) :: String.t()
  def to_string(mapping = %__MODULE__{}, atom) when is_atom(atom) do
    case lookup_original_string(mapping, atom) do
      {:atom, string} -> string
      {:wrapped_atom, string} -> string
      {:module, string} -> "Elixir.#{string}"
      :error -> Atom.to_string(atom)
    end
  end

  @spec inspect(t, atom) :: String.t()
  def inspect(mapping = %__MODULE__{}, atom) when is_atom(atom) do
    case lookup_original_string(mapping, atom) do
      {:atom, string} -> ":#{string}"
      {:wrapped_atom, string} -> ~s(:"#{string}")
      {:module, string} -> string
      :error -> inspect(atom)
    end
  end

  @spec lookup_original_string(t, atom) :: {:atom | :wrapped_atom | :module, String.t()} | :error
  def lookup_original_string(mapping = %__MODULE__{}, atom) when is_atom(atom) do
    case mapping.modules do
      %{^atom => string} ->
        {:module, string}

      _ ->
        case mapping.atoms do
          %{^atom => string} ->
            case mapping.extra_info do
              %{^atom => :wrapped} -> {:wrapped_atom, string}
              _ -> {:atom, string}
            end

          _ ->
            :error
        end
    end
  end

  @spec replace_in_string(t, String.t()) :: String.t()
  def replace_in_string(mapping, string) when is_binary(string) do
    if string =~ "Dune" do
      do_replace_in_string(mapping, string)
    else
      string
    end
  end

  @dune_atom_regex ~r/(Dune_Atom_\d+__|a?__Dune_atom_\d+__|Dune_Module_\d+__)/
  defp do_replace_in_string(mapping = %__MODULE__{}, string) do
    string_replace_map =
      %{}
      |> build_replace_map(mapping.modules, nil, &inspect/1)
      |> build_replace_map(mapping.atoms, mapping.extra_info, &Atom.to_string/1)

    String.replace(string, @dune_atom_regex, &Map.get(string_replace_map, &1, &1))
  end

  defp build_replace_map(map, sub_mapping, extra_info, to_string_fun) do
    for {subsitute_atom, original_string} <- sub_mapping, into: map do
      replace_by =
        case extra_info do
          %{^subsitute_atom => :wrapped} -> ~s("#{original_string}")
          _ -> original_string
        end

      {to_string_fun.(subsitute_atom), replace_by}
    end
  end

  @spec replace_in_result(t, Success.t() | Failure.t()) ::
          Success.t() | Failure.t()
  def replace_in_result(mapping, result)

  def replace_in_result(mapping, %Success{} = success) do
    %Success{
      success
      | inspected: replace_in_string(mapping, success.inspected),
        stdio: replace_in_string(mapping, success.stdio)
    }
  end

  def replace_in_result(mapping, %Failure{} = error) do
    %Failure{
      error
      | message: replace_in_string(mapping, error.message),
        stdio: replace_in_string(mapping, error.stdio)
    }
  end

  @spec to_existing_atom(t, String.t()) :: atom
  def to_existing_atom(mapping = %__MODULE__{}, string) when is_binary(string) do
    case fetch_existing_atom(mapping, string) do
      nil -> String.to_existing_atom(string)
      atom -> atom
    end
  end

  defp fetch_existing_atom(mapping, "Elixir." <> module_name) do
    Enum.find_value(mapping.modules, fn {subsitute_atom, original_string} ->
      if original_string == module_name do
        subsitute_atom
      end
    end)
  end

  defp fetch_existing_atom(mapping, atom_name) do
    Enum.find_value(mapping.atoms, fn {subsitute_atom, original_string} ->
      if original_string == atom_name do
        subsitute_atom
      end
    end)
  end
end
