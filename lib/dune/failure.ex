defmodule Dune.Failure do
  @moduledoc """
  A struct returned when `Dune` parsing or evaluation fails.

  Fields:
  - `message` (string): the error message to display to the user
  - `type` (atom): the nature of the error
  - `stdio` (string): captured standard output

  """

  @type error_type ::
          :restricted
          | :module_restricted
          | :module_conflict
          | :timeout
          | :exception
          | :parsing
          | :memory
          | :reductions

  @type t :: %__MODULE__{type: error_type, message: String.t(), stdio: binary}
  @enforce_keys [:type, :message]
  defstruct [:type, :message, stdio: ""]

  @doc false
  def restricted_function(module, fun, arity) do
    formatted_fun = format_function(module, fun, arity)
    message = "** (DuneRestrictedError) function #{formatted_fun} is restricted"

    %__MODULE__{type: :restricted, message: message}
  end

  @doc false
  def undefined_module(module, function, arity) do
    base_message = base_undefined_message(module, function, arity)

    message =
      IO.iodata_to_binary([base_message, "(module ", inspect(module), " is not available)"])

    %__MODULE__{type: :exception, message: message}
  end

  @doc false
  def undefined_function(module, function, arity) do
    base_message = base_undefined_message(module, function, arity)
    message = IO.iodata_to_binary([base_message, "or private"])

    %__MODULE__{type: :exception, message: message}
  end

  defp base_undefined_message(module, function, arity) do
    formatted_fun = format_function(module, function, arity)
    ["** (UndefinedFunctionError) function ", formatted_fun, " is undefined "]
  end

  defp format_function(kernel, fun, arity) when kernel in [nil, Kernel, Kernel.SpecialForms] do
    "#{fun}/#{arity}"
  end

  defp format_function(module, fun, arity) do
    "#{inspect(module)}.#{fun}/#{arity}"
  end
end
