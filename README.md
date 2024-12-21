# Dune

[![Hex Version](https://img.shields.io/hexpm/v/dune.svg)](https://hex.pm/packages/dune)
[![docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/dune/)
[![CI](https://github.com/functional-rewire/dune/workflows/CI/badge.svg)](https://github.com/functional-rewire/dune/actions?query=workflow%3ACI)

A sandbox for Elixir to safely evaluate untrusted code from user input.

[**Try it out on our online playground!**](https://playground.functional-rewire.com/)

`Dune` can be useful to develop playgrounds, online REPL, coding games, or
customizable business logic.

**Warning:** `Dune` cannot offer strong security guarantees (see the
[Security guarantees](#security-guarantees) section below). Besides, it is still
early stage: expect bugs and vulnerabilities.

## Features

- allowlist mechanism (customizable) to restrict execution to safe modules and
  functions: no access to environment variables, file system, network...
- code executed in an isolated process
- execution within configurable limits: timeout, maximum reductions and memory
  (inspired by [Luerl](https://github.com/rvirding/luerl))
- captured standard output
- atoms, without atom leaks: parsing and runtime do not
  [leak atoms](https://hexdocs.pm/elixir/String.html#to_atom/1) (i.e. does not
  keep
  [filling the atom table](https://learnyousomeerlang.com/starting-out-for-real#atoms)
  until the VM crashes)
- modules, without actual module creation: Dune does not let users define any
  actual module (would leak memory and modify the state of the VM globally), but
  `defmodule` simulates the basic behavior of a module, including private and
  recursive functions

```elixir
iex> Dune.eval_string("IO.puts(\"Hello world!\")")
%Dune.Success{inspected: ":ok", stdio: "Hello world!\n", value: :ok}

iex> Dune.eval_string("File.cwd!()")
%Dune.Failure{message: "** (DuneRestrictedError) function File.cwd!/0 is restricted", type: :restricted}

iex> Dune.eval_string("List.duplicate(:spam, 100_000)")
%Dune.Failure{message: "Execution stopped - memory limit exceeded", stdio: "", type: :memory}

iex> Dune.eval_string("Enum.product(1..100_000)")
%Dune.Failure{message: "Execution stopped - reductions limit exceeded", stdio: "", type: :reductions}
```

The list of modules and functions authorized by default is defined by the
[`Dune.Allowlist.Default`](https://hexdocs.pm/dune/Dune.Allowlist.Default.html#module-allowed-modules-functions)
module, but this list can be extended and customized (at your own risk!) using
[`Dune.Allowlist`](https://hexdocs.pm/dune/Dune.Allowlist.html).

If you need to keep the state between evaluations, you might consider
[`Dune.Session`](https://hexdocs.pm/dune/Dune.Session.html):

```elixir
iex> Dune.Session.new()
...> |> Dune.Session.eval_string("x = 1")
...> |> Dune.Session.eval_string("x + 2")
#Dune.Session<last_result: %Dune.Success{inspected: "3", stdio: "", value: 3}, ...>
```

`Dune.string_to_quoted/2` returns the AST corresponding to the provided
`string`, without leaking atoms:

```elixir
iex> Dune.string_to_quoted("foo(:bar)").inspected
"{:foo, [line: 1], [:bar]}"
```

## Limitations

`Dune` supports a fair subset of the base language, but it cannot safely support
advanced features (at least at this stage) such as:

- custom structs / behaviours / protocols
- concurrency / processes / OTP
- metaprogramming

## Security guarantees

Because of the approch being used, Dune cannot offer strong security guarantees,
and should not be considered a sufficient security layer by itself.

A best-effort approach is made to prevent attackers from getting outside of the
original process and from calling any function/macro outside of the allowlist.
However, it is impossible to prove that all escape paths have been completely
blocked. Due to how the Erlang VM works, an attacker able to escape the sandbox
could get full access to the VM without restriction.

See the
[EEF guidelines about sandboxing](https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/sandboxing)
for more information.

Use at your own risk and avoid running it directly on a server with any
sensitive access, e.g. to a database.

## Installation

The package can be installed by adding `dune` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:dune, "~> 0.3.11"}
  ]
end
```

Documentation can be found at
[https://hexdocs.pm/dune](https://hexdocs.pm/dune).

## FAQ

### Why can I still create atoms?

Atoms are converted by the parser and mapped to always use a given set of atoms.
So when you type `foo = bar(:baz)`, the atoms `:foo`, `:bar` and `:baz` won't
actually be created, but other atoms like `:atom1`, `:atom2` and `:atom3` are
going to be used instead.

So even if many user run various codes using many different variable and
function names, they will all pull from the same pool of atoms.

### Why can I still create modules?

Modules are being defined globally within the VM, making it both an isolation
concern and a memory concern. But modules are an important part of the Elixir
language, and are especially important for learning platforms.

Dune implements an alternative `defmodule`, relying on maps of anonymous
functions at runtime and should reproduce the basic behavior of actual modules,
with support for recursive and private functions.

### Why is the behavior different than Elixir when doing X?

As explained above, some parts of the language are actually being completely
reimplemented because the original version could not be safely sandboxed: atoms,
modules... While these alternative implementation aim to be as close as possible
to the original ones, they might differ in some cases, because the code being
executed is actually different.

### Why can't I do X?

Some parts of the language are being restricted because they present a direct
security risk, while some other would need to be reimplemented in an alternative
way and therefore need a consequent amount of work that hasn't been done yet.
