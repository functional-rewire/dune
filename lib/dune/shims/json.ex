if Code.ensure_loaded?(JSON) do
  defmodule Dune.Shims.JSON do
    @moduledoc false

    alias Dune.AtomMapping

    def protocol_encode(env, value, encoder) when is_non_struct_map(value) do
      case :maps.next(:maps.iterator(value)) do
        :none ->
          "{}"

        {key, value, iterator} ->
          [
            ?{,
            key(env, key, encoder),
            ?:,
            encoder.(value, encoder) | next(env, iterator, encoder)
          ]
      end
    end

    def protocol_encode(env, value, encoder)
        when is_atom(value) and value not in [nil, true, false] do
      encoder.(AtomMapping.to_string(env.atom_mapping, value), encoder)
    end

    def protocol_encode(_env, value, encoder) do
      JSON.protocol_encode(value, encoder)
    end

    defp next(env, iterator, encoder) do
      case :maps.next(iterator) do
        :none ->
          "}"

        {key, value, iterator} ->
          [
            ?,,
            key(env, key, encoder),
            ?:,
            encoder.(value, encoder) | next(env, iterator, encoder)
          ]
      end
    end

    defp key(env, key, encoder) when is_atom(key),
      do: encoder.(AtomMapping.to_string(env.atom_mapping, key), encoder)

    defp key(_env, key, encoder) when is_binary(key), do: encoder.(key, encoder)
    defp key(_env, key, encoder), do: encoder.(String.Chars.to_string(key), encoder)

    def encode!(env, term) do
      encode!(env, term, &protocol_encode(env, &1, &2))
    end

    def encode!(_env, term, encoder) do
      IO.iodata_to_binary(encoder.(term, encoder))
    end

    def encode_to_iodata!(env, term) do
      encode_to_iodata!(env, term, &protocol_encode(env, &1, &2))
    end

    def encode_to_iodata!(_env, term, encoder) do
      encoder.(term, encoder)
    end
  end
end
