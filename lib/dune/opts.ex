defmodule Dune.Opts do
  @moduledoc """
  Defines and validates the options for `Dune`.

  The available options are explained below:

  ### Parsing restriction options

  - `atom_pool_size`:
    Defines the maximum total number of atoms that can be created.
    Must be an integer `>= 0`. Defaults to `5000`.
    See the [section below](#module-extra-note-about-atom_pool_size) for more information.
  - `max_length`:
    Defines the maximum length of code strings that can be parsed.
    Defaults to `5000`.

  ### Execution restriction options

  - `allowlist`:
    Defines which module and functions are considered safe or restricted.
    Should be a module implementing the `Dune.Allowlist` behaviour.
    Defaults to `Dune.Allowlist.Default`.
  - `max_heap_size`:
    Limits the memory usage of the evaluation process using the
    [`max_heap_size` flag](https://erlang.org/doc/man/erlang.html#process_flag_max_heap_size).
    Should be an integer `> 0`. Defaults to `30_000`.
  - `max_reductions`:
    Limits the number of CPU cycles of the evaluation process.
    The erlang pre-emptive scheduler is using reductions to measure work being done by processes,
    which is useful to prevent users to run CPU intensive code such as infinite loops.
    Should be an integer `> 0`. Defaults to `30_000`.
  - `timeout`:
    Limits the time the evaluation process is authorized to run (in milliseconds).
    Should be an integer `> 0`. Defaults to `50`.

  The evaluation process will still need to parse and execute the sanitized AST, so using
  too low limits here would leave only a small margin to actually run user code.

  ### Other options

  - `pretty`:
    Use pretty printing when inspecting the result.
    Should be a boolean. Defaults to `false`.

  - `inspect_sort_maps`:
    Sort maps when inspecting the result, useful to keep the output deterministic.
    Should be a boolean. Defaults to `false`. Only works since Elixir >= 1.14.4.

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
          max_length: pos_integer,
          allowlist: module,
          max_heap_size: pos_integer,
          max_reductions: pos_integer,
          timeout: pos_integer,
          pretty: boolean,
          inspect_sort_maps: boolean
        }

  defstruct atom_pool_size: 5000,
            max_length: 5000,
            allowlist: Dune.Allowlist.Default,
            max_heap_size: 50_000,
            max_reductions: 30_000,
            timeout: 50,
            pretty: false,
            inspect_sort_maps: false

  @doc """
  Validates untrusted options from a keyword or a map and returns a `Dune.Opts` struct.

  ## Examples

      iex> Dune.Opts.validate!([])
      %Dune.Opts{
        allowlist: Dune.Allowlist.Default,
        atom_pool_size: 5000,
        max_heap_size: 50000,
        max_length: 5000,
        max_reductions: 30000,
        pretty: false,
        timeout: 50
      }

      iex> Dune.Opts.validate!(atom_pool_size: 10)
      %Dune.Opts{atom_pool_size: 10, allowlist: Dune.Allowlist.Default}

      iex> Dune.Opts.validate!(atom_pool_size: -10)
      ** (ArgumentError) atom_pool_size should be an integer >= 0

      iex> Dune.Opts.validate!(max_length: 0)
      ** (ArgumentError) atom_pool_size should be an integer > 0

      iex> Dune.Opts.validate!(allowlist: DoesNotExists)
      ** (ArgumentError) could not load module DoesNotExists due to reason :nofile

      iex> Dune.Opts.validate!(allowlist: List)
      ** (ArgumentError) List does not implement the Dune.Allowlist behaviour

      iex> Dune.Opts.validate!(max_reductions: 10_000, max_heap_size: 10_000, timeout: 20)
      %Dune.Opts{max_heap_size: 10_000, max_reductions: 10_000, timeout: 20}

      iex> Dune.Opts.validate!(max_heap_size: 0)
      ** (ArgumentError) max_heap_size should be an integer > 0

      iex> Dune.Opts.validate!(max_reductions: 0)
      ** (ArgumentError) max_reductions should be an integer > 0

      iex> Dune.Opts.validate!(timeout: "55")
      ** (ArgumentError) timeout should be an integer > 0

      iex> Dune.Opts.validate!(pretty: :maybe)
      ** (ArgumentError) pretty should be a boolean

  """
  @spec validate!(Keyword.t() | map) :: t
  def validate!(opts) do
    struct(__MODULE__, opts) |> do_validate()
  end

  defp do_validate(%{atom_pool_size: atom_pool_size})
       when not (is_integer(atom_pool_size) and atom_pool_size >= 0) do
    raise ArgumentError, message: "atom_pool_size should be an integer >= 0"
  end

  defp do_validate(%{max_length: max_length})
       when not (is_integer(max_length) and max_length > 0) do
    raise ArgumentError, message: "atom_pool_size should be an integer > 0"
  end

  defp do_validate(%{allowlist: allowlist}) when not is_atom(allowlist) do
    raise ArgumentError, message: "allowlist should be a module"
  end

  defp do_validate(%{max_reductions: max_reductions})
       when not (is_integer(max_reductions) and max_reductions > 0) do
    raise ArgumentError, message: "max_reductions should be an integer > 0"
  end

  defp do_validate(%{max_heap_size: max_heap_size})
       when not (is_integer(max_heap_size) and max_heap_size > 0) do
    raise ArgumentError, message: "max_heap_size should be an integer > 0"
  end

  defp do_validate(%{timeout: timeout}) when not (is_integer(timeout) and timeout > 0) do
    raise ArgumentError, message: "timeout should be an integer > 0"
  end

  defp do_validate(%{pretty: pretty}) when not is_boolean(pretty) do
    raise ArgumentError, message: "pretty should be a boolean"
  end

  defp do_validate(%{inspect_sort_maps: sort}) when not is_boolean(sort) do
    raise ArgumentError, message: "inspect_sort_maps should be a boolean"
  end

  defp do_validate(opts = %{allowlist: allowlist}) do
    Allowlist.ensure_implements_behaviour!(allowlist)

    opts
  end
end
