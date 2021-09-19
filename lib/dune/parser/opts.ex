defmodule Dune.Parser.Opts do
  @moduledoc """
  Defines the parsing options for Dune,
  which restrict the code that can safely be executed.

  See `Dune.Eval.Opts` for runtime restriction options.

  The available fields are:
  - `atom_pool_size`:
    Defines the maximum total number of atoms that can be created.
    Must be an integer `>= 0`. Defaults to `5000`.
  - `max_length`:
    Defines the maximum length of code strings that can be parsed.
    Defaults to `5000`.
  - `allowlist`:
    Defines which module and functions are considered safe or restricted.
    Should be a module implementing the `Dune.Allowlist` behaviour.
    Defaults to `Dune.Allowlist.Default`.

  ### Extra note about `atom_pool_size`

  Atoms are reused from one evaluation to the other so the total is not
  expected to grow. Atoms will not be leaked.

  Also, the atom pool is actually split into several pools: regular atoms, module names,
  unused variable names, ...
  So defining a value of `100` does not mean that `100` atoms will be available, but
  rather `25` of each type.

  Atoms being very lightweight, there is no need to use a low value, as long
  as there is an upper bound preventing atom leaks.

  """

  alias Dune.Allowlist

  @type t :: %__MODULE__{
          atom_pool_size: non_neg_integer,
          allowlist: module
        }

  defstruct atom_pool_size: 5000, max_length: 5000, allowlist: Dune.Allowlist.Default

  @doc """
  Validates untrusted options from a keyword or a map and returns a `Dune.Parser.Opts` struct.

  ## Examples

      iex> Dune.Parser.Opts.validate!([])
      %Dune.Parser.Opts{atom_pool_size: 5000, allowlist: Dune.Allowlist.Default}

      iex> Dune.Parser.Opts.validate!(atom_pool_size: 10)
      %Dune.Parser.Opts{atom_pool_size: 10, allowlist: Dune.Allowlist.Default}

      iex> Dune.Parser.Opts.validate!(atom_pool_size: -10)
      ** (ArgumentError) atom_pool_size should be an integer >= 0

      iex> Dune.Parser.Opts.validate!(allowlist: DoesNotExists)
      ** (ArgumentError) could not load module DoesNotExists due to reason :nofile

      iex> Dune.Parser.Opts.validate!(allowlist: List)
      ** (ArgumentError) List does not implement the Dune.Allowlist behaviour

  """
  @spec validate!(Keyword.t() | map) :: t
  def validate!(opts) do
    struct(__MODULE__, opts) |> do_validate()
  end

  defp do_validate(%{atom_pool_size: atom_pool_size})
       when not (is_integer(atom_pool_size) and atom_pool_size >= 0) do
    raise ArgumentError, message: "atom_pool_size should be an integer >= 0"
  end

  defp do_validate(%{allowlist: allowlist}) when not is_atom(allowlist) do
    raise ArgumentError, message: "allowlist should be a module"
  end

  defp do_validate(opts = %{allowlist: allowlist}) do
    Allowlist.ensure_implements_behaviour!(allowlist)

    opts
  end
end
