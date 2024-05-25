defmodule Dune.Success do
  @moduledoc """
  A struct returned when `Dune` evaluation succeeds.

  Fields:
  - `value` (term): the value which was actually returned at runtime.
    Should not be displayed to the user, might be different from what the user expects.
  - `inspected` (string): safely inspected `value` to be displayed to the user
  - `stdio` (string): captured standard output

  `value` contains the actual value used at runtime, so atoms will be different from the ones
  displayed to the user (see `Dune.eval_string/2`).
  """

  @type t :: %__MODULE__{
          value: term,
          inspected: String.t(),
          stdio: binary
        }
  @enforce_keys [:value, :inspected, :stdio]
  defstruct @enforce_keys
end
