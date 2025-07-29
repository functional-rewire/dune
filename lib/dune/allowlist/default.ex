defmodule Dune.Allowlist.Default do
  @moduledoc """
  The default `Dune.Allowlist` module to be used to allow or restrict
  functions and macros that can be safely executed.

  ## Examples

      iex> Dune.Allowlist.Default.fun_status(Kernel, :+, 2)
      :allowed

      iex> Dune.Allowlist.Default.fun_status(String, :to_atom, 1)
      :restricted

      iex> Dune.Allowlist.Default.fun_status(Atom, :to_string, 1)
      {:shimmed, Dune.Shims.Atom, :to_string}

      iex> Dune.Allowlist.Default.fun_status(Kernel, :foo, 1)
      :undefined_function

      iex> Dune.Allowlist.Default.fun_status(Bar, :foo, 1)
      :undefined_module

      iex> Dune.Allowlist.Default.fun_status(Kernel.SpecialForms, :quote, 2)
      :restricted

  ## Allowed modules / functions

  __DUNE_ALLOWLIST_FUNCTIONS__

  """

  use Dune.Allowlist

  alias Dune.Shims

  @special_forms_allowed ~w[
    {}
    %{}
    <<>>
    =
    ^
    case
    cond
    fn
    for
    with
    ::
    __aliases__
  ]a

  @kernel_operators ~w[
    |>
    +
    ++
    -
    --
    *
    **
    /
    <>
    ==
    ===
    !=
    !==
    =~
    >
    >=
    <
    <=
    and
    or
    &&
    ||
    !
    ..
    ..//
  ]a

  @kernel_guards ~w[
    is_integer
    is_binary
    is_bitstring
    is_atom
    is_boolean
    is_integer
    is_float
    is_number
    is_list
    is_map
    is_map_key
    is_nil
    is_reference
    is_tuple
    is_exception
    is_struct
    is_function
  ]a

  @kernel_macros ~w[
    if
    unless
    in
    match?
    then
    tap
    raise
  ]a

  @kernel_sigils ~w[
    sigil_C
    sigil_D
    sigil_N
    sigil_R
    sigil_S
    sigil_T
    sigil_U
    sigil_c
    sigil_r
    sigil_s
    sigil_w
  ]a

  @kernel_functions ~w[
    abs
    binary_part
    bit_size
    byte_size
    ceil
    div
    elem
    floor
    get_and_update_in
    get_in
    hd
    length
    make_ref
    map_size
    max
    min
    not
    pop_in
    put_elem
    put_in
    rem
    round
    self
    tl
    trunc
    tuple_size
    update_in
  ]a

  # TODO Remove when dropping support for Elixir 1.16
  extra_kernel_functions =
    if System.version() |> Version.compare("1.17.0-rc.0") != :lt,
      do: [:to_timeout, :is_non_struct_map],
      else: []

  @kernel_allowed extra_kernel_functions ++
                    @kernel_operators ++
                    @kernel_guards ++ @kernel_macros ++ @kernel_sigils ++ @kernel_functions

  @kernel_shims [
    apply: {Shims.Kernel, :safe_apply},
    inspect: {Shims.Kernel, :safe_inspect},
    to_string: {Shims.Kernel, :safe_to_string},
    to_charlist: {Shims.Kernel, :safe_to_charlist},
    sigil_w: {Shims.Kernel, :safe_sigil_w},
    sigil_W: {Shims.Kernel, :safe_sigil_W},
    throw: {Shims.Kernel, :safe_throw},
    dbg: {Shims.Kernel, :safe_dbg}
  ]

  @erlang_allowed [
    :*,
    :+,
    :++,
    :-,
    :--,
    :/,
    :"/=",
    :<,
    :"=/=",
    :"=:=",
    :"=<",
    :==,
    :>,
    :>=,
    :abs,
    :adler32,
    :adler32_combine,
    :and,
    :append_element,
    :band,
    :binary_part,
    :binary_to_float,
    :binary_to_integer,
    :binary_to_list,
    :bit_size,
    :bitstring_to_list,
    :bnot,
    :bor,
    :bsl,
    :bsr,
    :bxor,
    :byte_size,
    :ceil,
    :convert_time_unit,
    :crc32,
    :crc32_combine,
    :date,
    :delete_element,
    :div,
    :element,
    :float,
    :float_to_binary,
    :float_to_list,
    :floor,
    :hd,
    :insert_element,
    :integer_to_binary,
    :integer_to_list,
    :iolist_size,
    :iolist_to_binary,
    :iolist_to_iovec,
    :is_atom,
    :is_binary,
    :is_bitstring,
    :is_boolean,
    :is_float,
    :is_function,
    :is_integer,
    :is_list,
    :is_map,
    :is_map_key,
    :is_number,
    :is_pid,
    :is_port,
    :is_record,
    :is_reference,
    :is_tuple,
    :length,
    :list_to_binary,
    :list_to_bitstring,
    :list_to_float,
    :list_to_integer,
    :localtime,
    :localtime_to_universaltime,
    :make_ref,
    :make_tuple,
    :map_get,
    :map_size,
    :max,
    :md5,
    :md5_final,
    :md5_init,
    :md5_update,
    :min,
    :monotonic_time,
    :not,
    :or,
    :phash2,
    :ref_to_list,
    :rem,
    :round,
    :setelement,
    :size,
    :split_binary,
    :system_time,
    :time,
    :time_offset,
    :timestamp,
    :tl,
    :trunc,
    :tuple_size,
    :tuple_to_list,
    :unique_integer,
    :universaltime,
    :universaltime_to_localtime,
    :xor
  ]

  @erlang_shims [
    apply: {Shims.Kernel, :safe_apply}
  ]

  @io_allowed ~w[
    chardata_to_string
    iodata_length
    iodata_to_binary
  ]a

  @io_shims [
    puts: {Shims.IO, :puts},
    inspect: {Shims.IO, :inspect}
  ]

  allow Kernel.SpecialForms, only: @special_forms_allowed

  allow Kernel, only: @kernel_allowed, shims: @kernel_shims
  allow Access, :all
  allow String, except: ~w[to_atom to_existing_atom]a
  allow Regex, :all
  allow Map, :all
  allow MapSet, :all
  allow Keyword, :all
  allow Tuple, :all
  allow List, except: ~w[to_atom to_existing_atom]a
  allow Enum, shims: [join: {Shims.Enum, :join}, map_join: {Shims.Enum, :map_join}]
  # TODO double check
  allow Stream, :all
  allow Range, :all
  allow Integer, :all
  allow Float, :all

  allow Atom,
    except: ~w[to_char_list]a,
    shims: [to_string: {Shims.Atom, :to_string}, to_charlist: {Shims.Atom, :to_charlist}]

  if Code.ensure_loaded?(JSON) do
    allow JSON,
      only: ~w[decode decode!]a,
      shims: Enum.map(~w[protocol_encode encode! encode_to_iodata!]a, &{&1, {Shims.JSON, &1}})
  end

  allow Date, :all
  allow DateTime, :all
  allow NaiveDateTime, :all

  # TODO Remove when dropping support for Elixir 1.16
  if System.version() |> Version.compare("1.17.0-rc.0") != :lt do
    allow Duration, :all
  end

  allow Calendar, except: ~w[put_time_zone_database]a
  allow Calendar.ISO, :all
  allow Time, :all
  allow Base, :all
  allow URI, :all
  allow Version, :all
  allow Bitwise, :all
  allow Function, only: ~w[identity]a
  allow IO, only: @io_allowed, shims: @io_shims
  allow Process, only: [:sleep]

  allow :erlang, only: @erlang_allowed, shims: @erlang_shims
  allow :math, :all
  allow :binary, :all
  allow :lists, :all
  allow :array, :all
  allow :maps, :all
  allow :gb_sets, :all
  allow :gb_trees, :all
  allow :ordsets, :all
  allow :orddict, :all
  allow :proplists, :all
  allow :queue, :all
  allow :string, :all
  allow :rand, :all
  # note: :unicode is not safe and should be shimmed due to "structural sharing bombs"

  # note: flat_size is unsafe due to "structural sharing bombs"
  allow :erts_debug, only: ~w[same size size_shared]a
  allow :zlib, only: ~w[zip unzip gzip gunzip compress uncompress]a
end
