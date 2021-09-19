defmodule Dune.Eval.Opts do
  @moduledoc """
  Defines the evaluation options for Dune,
  which restrict the VM resources allocated to execute user code.

  See `Dune.Parser.Opts` for parsing-time restriction options.

  The available fields are:
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

  """

  @type t :: %__MODULE__{
          max_heap_size: pos_integer,
          max_reductions: pos_integer,
          timeout: pos_integer
        }

  defstruct max_heap_size: 30_000, max_reductions: 30_000, timeout: 50

  @doc """
  Validates untrusted options from a keyword or a map and returns a `Dune.Eval.Opts` struct.

  ## Examples

      iex> Dune.Eval.Opts.validate!([])
      %Dune.Eval.Opts{max_heap_size: 30_000, max_reductions: 30_000, timeout: 50}

      iex> Dune.Eval.Opts.validate!(max_reductions: 10_000, max_heap_size: 10_000, timeout: 20)
      %Dune.Eval.Opts{max_heap_size: 10_000, max_reductions: 10_000, timeout: 20}

      iex> Dune.Eval.Opts.validate!(max_heap_size: 0)
      ** (ArgumentError) max_heap_size should be an integer > 0

      iex> Dune.Eval.Opts.validate!(max_reductions: 0)
      ** (ArgumentError) max_reductions should be an integer > 0

      iex> Dune.Eval.Opts.validate!(timeout: "55")
      ** (ArgumentError) timeout should be an integer > 0

  """
  @spec validate!(Keyword.t() | map) :: t
  def validate!(opts) do
    struct(__MODULE__, opts) |> do_validate()
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

  defp do_validate(valid) do
    valid
  end
end
