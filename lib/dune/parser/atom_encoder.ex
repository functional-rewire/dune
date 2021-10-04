defmodule Dune.Parser.AtomEncoder do
  @moduledoc false

  alias Dune.AtomMapping

  @type mapping :: [{atom, String.t()}]

  @atom_categories 4

  @elixir_modules [
    Kernel,
    Kernel.SpecialForms,
    Atom,
    Base,
    Bitwise,
    Date,
    DateTime,
    Exception,
    Float,
    Function,
    Integer,
    Module,
    NaiveDateTime,
    Record,
    Regex,
    String,
    Time,
    Tuple,
    URI,
    Version,
    Version.Requirement,
    Access,
    Date.Range,
    Enum,
    Keyword,
    List,
    Map,
    MapSet,
    Range,
    Stream,
    File,
    File.Stat,
    File.Stream,
    IO,
    IO.ANSI,
    IO.Stream,
    OptionParser,
    Path,
    Port,
    StringIO,
    System,
    Calendar,
    Calendar.ISO,
    Calendar.TimeZoneDatabase,
    Calendar.UTCOnlyTimeZoneDatabase,
    Agent,
    Application,
    Config,
    Config.Provider,
    Config.Reader,
    DynamicSupervisor,
    GenServer,
    Node,
    Process,
    Registry,
    Supervisor,
    Task,
    Task.Supervisor,
    Collectable,
    Enumerable,
    Inspect,
    Inspect.Algebra,
    Inspect.Opts,
    List.Chars,
    Protocol,
    String.Chars,
    Code,
    Kernel.ParallelCompiler,
    Macro,
    Macro.Env,
    Behaviour,
    Dict,
    GenEvent,
    HashDict,
    HashSet,
    Set,
    Supervisor.Spec,
    ArgumentError,
    ArithmeticError,
    BadArityError,
    BadBooleanError,
    BadFunctionError,
    BadMapError,
    BadStructError,
    CaseClauseError,
    Code.LoadError,
    CompileError,
    CondClauseError,
    Enum.EmptyError,
    Enum.OutOfBoundsError,
    ErlangError,
    File.CopyError,
    File.Error,
    File.LinkError,
    File.RenameError,
    FunctionClauseError,
    IO.StreamError,
    Inspect.Error,
    KeyError,
    MatchError,
    Module.Types.Error,
    OptionParser.ParseError,
    Protocol.UndefinedError,
    Regex.CompileError,
    RuntimeError,
    SyntaxError,
    SystemLimitError,
    TokenMissingError,
    TryClauseError,
    DuneRestrictedError,
    UnicodeConversionError,
    Version.InvalidRequirementError,
    Version.InvalidVersionError,
    WithClauseError
  ]

  # TODO add
  @erlang_modules [:math]

  @elixir_reprs @elixir_modules
                |> Enum.flat_map(&Module.split/1)
                |> Enum.map(&{&1, String.to_existing_atom(&1)})

  @erlang_reprs Enum.map(@erlang_modules, &{Atom.to_string(&1), &1})

  @module_reprs Map.new(@elixir_reprs ++ @erlang_reprs)

  @spec load_atom_mapping(AtomMapping.t() | nil) :: :ok
  def load_atom_mapping(nil), do: :ok

  def load_atom_mapping(%AtomMapping{atoms: atoms}) do
    count = Enum.count(atoms)
    Process.put(:__Dune_atom_count__, count)

    Enum.each(atoms, fn {atom, binary} ->
      Process.put({:__Dune_atom__, binary}, atom)
    end)
  end

  @spec static_atoms_encoder(String.t(), non_neg_integer()) :: {:ok, atom} | {:error, String.t()}
  def static_atoms_encoder(binary, pool_size)
      when is_binary(binary) and is_integer(pool_size) do
    case @module_reprs do
      %{^binary => atom} ->
        {:ok, atom}

      _ ->
        cond do
          binary =~ "Dune" ->
            {:error, "Atoms containing `Dune` are restricted for safety"}

          module_name = extract_elixir_prefixed_module(binary) ->
            with {:ok, atom} <- do_static_atoms_encoder(module_name, pool_size) do
              {:ok, {:__aliases__, [], [Elixir, atom]}}
            end

          true ->
            do_static_atoms_encoder(binary, pool_size)
        end
    end
  end

  defp extract_elixir_prefixed_module("Elixir." <> rest) do
    charlist = String.to_charlist(rest)

    case Code.cursor_context(charlist) do
      {:alias, ^charlist} ->
        rest

      _ ->
        nil
    end
  end

  defp extract_elixir_prefixed_module(_binary), do: nil

  defp do_static_atoms_encoder(binary, pool_size) do
    process_key = {:__Dune_atom__, binary}

    case Process.get(process_key, nil) do
      nil -> do_static_atoms_encoder(binary, process_key, pool_size)
      atom when is_atom(atom) -> {:ok, atom}
    end
  end

  defp do_static_atoms_encoder(binary, process_key, pool_size) do
    {:ok, String.to_existing_atom(binary)}
  rescue
    ArgumentError ->
      case new_atom(binary, pool_size) do
        {:ok, atom} ->
          Process.put(process_key, atom)
          {:ok, atom}

        {:error, error} ->
          {:error, error}
      end
  end

  @spec plain_atom_mapping :: AtomMapping.t()
  def plain_atom_mapping() do
    for {{:__Dune_atom__, binary}, atom} <- Process.get() do
      {atom, binary}
    end
    |> AtomMapping.from_atoms()
  end

  defp new_atom(binary, pool_size) do
    count = Process.get(:__Dune_atom_count__, 0) + 1

    if count * @atom_categories > pool_size do
      {:error, "atom_pool_size exceeded, failed to parse atom"}
    else
      Process.put(:__Dune_atom_count__, count)
      atom = do_new_atom(binary, count)
      {:ok, atom}
    end
  end

  defp do_new_atom(<<h::8, _::binary>>, count) when h in ?A..?Z do
    :"Dune_Atom_#{count}__"
  end

  defp do_new_atom("_" <> _binary, count) do
    :"__Dune_atom_#{count}__"
  end

  defp do_new_atom(binary, count) when is_binary(binary) do
    :"a__Dune_atom_#{count}__"
  end

  @spec encode_modules(Macro.t(), AtomMapping.t(), AtomMapping.t() | nil) ::
          {Macro.t(), AtomMapping.t()}
  def encode_modules(ast, plain_atom_mapping, existing_mapping) do
    initial_acc = get_module_acc(existing_mapping)

    {new_ast, acc} =
      Macro.postwalk(ast, initial_acc, fn
        {:__aliases__, ctx, atoms}, acc ->
          {modules, new_acc} = remove_elixir_prefix(atoms) |> map_modules_ast(acc)
          {{:__aliases__, ctx, modules}, new_acc}

        other, acc ->
          {other, acc}
      end)

    atom_mapping = build_module_mapping(acc, plain_atom_mapping)

    {new_ast, atom_mapping}
  end

  defp get_module_acc(nil), do: %{}

  defp get_module_acc(%AtomMapping{atoms: atoms, modules: modules}) do
    reverse_atoms = Map.new(atoms, fn {atom, string} -> {string, atom} end)

    Map.new(modules, fn {atom, string} ->
      atoms = String.split(string, ".") |> Enum.map(&Map.fetch!(reverse_atoms, &1))
      {atoms, atom}
    end)
  end

  defp remove_elixir_prefix([Elixir | atoms]) when atoms not in [[], [Elixir]], do: atoms
  defp remove_elixir_prefix(atoms), do: atoms

  defp map_modules_ast(atoms, acc) do
    case acc do
      %{^atoms => module_name} ->
        {[module_name], acc}

      _ ->
        try do
          atoms |> Enum.join(".") |> then(&"Elixir.#{&1}") |> String.to_existing_atom()
        rescue
          ArgumentError ->
            module_name = :"Dune_Module_#{map_size(acc) + 1}__"
            {[module_name], Map.put(acc, atoms, module_name)}
        else
          _ ->
            {atoms, acc}
        end
    end
  end

  defp build_module_mapping(acc, plain_atom_mapping) do
    modules =
      Enum.map(acc, fn {atoms, module_name} ->
        string = Enum.map_join(atoms, ".", &AtomMapping.to_string(plain_atom_mapping, &1))
        module = Module.concat([module_name])
        {module, string}
      end)

    AtomMapping.add_modules(plain_atom_mapping, modules)
  end
end
