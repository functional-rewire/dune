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
    reraise
    throw
  ]a

  @kernel_sigils ~w[
    sigil_C
    sigil_D
    sigil_N
    sigil_R
    sigil_S
    sigil_T
    sigil_U
    sigil_W
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

  @kernel_allowed @kernel_operators ++
                    @kernel_guards ++ @kernel_macros ++ @kernel_sigils ++ @kernel_functions

  @kernel_shims [
    apply: {Shims.Kernel, :safe_apply},
    inspect: {Shims.Kernel, :safe_inspect},
    to_string: {Shims.Kernel, :safe_to_string},
    to_charlist: {Shims.Kernel, :safe_to_charlist},
    sigil_w: {Shims.Kernel, :safe_sigil_w},
    sigil_W: {Shims.Kernel, :safe_sigil_W}
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

  allow Date, :all
  allow DateTime, :all
  allow NaiveDateTime, :all
  allow Calendar, except: ~w[put_time_zone_database]a
  allow Calendar.ISO, :all
  allow Time, :all
  allow Base, :all
  allow URI, :all
  allow Bitwise, :all
  allow Function, only: ~w[identity]a
  allow IO, only: @io_allowed, shims: @io_shims
  allow Process, only: [:sleep]

  # TODO erlang, [only: @erlang_allowed]
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
  allow :unicode, :all
  allow :rand, :all
  allow :counters, :all
  allow :erts_debug, only: ~w[same size size_shared flat_size]a
  allow :zlib, only: ~w[zip unzip gzip gunzip compress uncompress]a
end
