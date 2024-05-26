defmodule Dune.Parser.StringParser do
  @moduledoc false

  alias Dune.{AtomMapping, Failure, Opts}
  alias Dune.Helpers.Diagnostics
  alias Dune.Parser.{AtomEncoder, UnsafeAst}

  @typep previous_session :: %{atom_mapping: AtomMapping.t()}

  # TODO options: parse timeout & max atoms
  @spec parse_string(String.t(), Opts.t(), previous_session | nil, boolean) ::
          UnsafeAst.t() | Failure.t()
  def parse_string(string, opts, previous_session, encode_modules? \\ true)
      when is_binary(string) and is_boolean(encode_modules?) do
    # import: do in a different process because the AtomEncoder pollutes the Process dict
    fn -> do_parse_string(string, opts, previous_session, encode_modules?) end
    |> Task.async()
    |> Task.await()
  end

  defp do_parse_string(
         string,
         %Opts{atom_pool_size: pool_size},
         previous_session,
         encode_modules?
       ) do
    maybe_load_atom_mapping(previous_session)
    encoder = fn binary, _ctx -> AtomEncoder.static_atoms_encoder(binary, pool_size) end

    {result, diagnostics} =
      Diagnostics.with_diagnostics_polyfill(fn ->
        Code.string_to_quoted(string, static_atoms_encoder: encoder, existing_atoms_only: true)
      end)

    case result do
      {:ok, ast} ->
        maybe_encode_modules(ast, previous_session, encode_modules?)
        |> Diagnostics.prepend_diagnostics(diagnostics)

      {:error, {_ctx, error, token}} ->
        handle_failure(error, token)
    end
  end

  defp maybe_load_atom_mapping(nil), do: :ok

  defp maybe_load_atom_mapping(%{atom_mapping: atom_mapping}) do
    AtomEncoder.load_atom_mapping(atom_mapping)
  end

  defp maybe_encode_modules(ast, previous_session, encode_modules?) do
    plain_atom_mapping = AtomEncoder.plain_atom_mapping()

    {new_ast, atom_mapping} =
      if encode_modules? do
        existing_mapping = previous_session[:atom_mapping]
        AtomEncoder.encode_modules(ast, plain_atom_mapping, existing_mapping)
      else
        {ast, plain_atom_mapping}
      end

    %UnsafeAst{ast: new_ast, atom_mapping: atom_mapping}
  end

  defp handle_failure("Atoms containing" <> _ = error, token) do
    %Failure{message: error <> token, type: :restricted}
  end

  defp handle_failure(error, token) do
    failure = do_handle_failure(error, token)

    AtomEncoder.plain_atom_mapping()
    |> AtomMapping.replace_in_result(failure)
  end

  defp do_handle_failure({error, explanation}, token)
       when is_binary(error) and is_binary(explanation) do
    message = IO.iodata_to_binary([error, token, explanation])
    %Failure{message: message, type: :parsing}
  end

  defp do_handle_failure(error, token) when is_binary(error) do
    %Failure{message: error <> token, type: :parsing}
  end
end
