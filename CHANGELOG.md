# Changelog

## Dev

## v0.3.4 (2023-09-14)

### Bug fixes

- Fix `UndefinedFunctionError` when using external modules in a custom allowlist

## v0.3.3 (2023-08-13)

### Bug fixes

- Fix vulnerability allowing an attacker to crash the VM using bitstrings

## v0.3.2 (2023-08-12)

### Enhancements

- `dbg/1` uses pretty printing

### Bug fixes

- Fix error message on restricted `dbg/0`

## v0.3.1 (2023-08-12)

### Enhancements

- Add support for `dbg/1`

### Bug fixes

- Properly distinguish user code `throw/1` from internal ones

## v0.3.0 (2023-08-09)

### Breaking changes

- Drop support for Elixir 1.13
- Compile errors are now returned as a separate type `:compile_error`

### Enhancements

- Support Elixir 1.15
- Capture compile diagnostics (Elixir >= 1.15)

### Bug fixes

- Better handle `UndefinedFunctionError` for dynamic module names

## v0.2.6 (2022-10-17)

### Enhancements

- Support Elixir 1.14

## v0.2.5 (2022-08-25)

### Bug fixes

- Restrict the use of `:counters` in `Dune.Allowlist.Default`, since it can leak
  memory

## v0.2.4 (2022-07-13)

### Bug fixes

- Validate module names in `defmodule`, reject `nil` or booleans

## v0.2.3 (2022-04-13)

### Bug fixes

- `Dune.string_to_quoted/2` quotes modules with `.` correctly
- OTP 25 regression: keep a clean stacktrace for exceptions

## v0.2.2 (2022-04-05)

### Enhancements

- Add `Dune.string_to_quoted/2` to make it possible to visualize AST
- Merged parsing and eval options in a single `Dune.Opts` for simplicity
- Add a `pretty` option to inspect result
- Better error message when `def/2` and `defp/2` called outside a module

### Breaking changes

- Removed Dune.Parser.Opts and Dune.Eval.Opts

## v0.2.1 (2022-03-19)

### Bug fixes

- Handle default arguments in functions
- Handle conflicting `def` and `defp` with same name/arity

## v0.2.0 (2022-01-02)

### Breaking changes

- Support Elixir 1.13, drop support for 1.12
- This fixes a [bug in atoms](https://github.com/elixir-lang/elixir/pull/11313)
  was due to the Elixir parser

## v0.1.2 (2021-10-17)

### Enhancements

- Allow safe functions from the `:erlang` module

### Bug fixes

- Fix bug when calling custom function in nested AST

## v0.1.1 (2021-10-16)

### Bug fixes

- Prevent atom leaks due to `Code.string_to_quoted/2` not respecting
  `static_atoms_encoder`
- Handle Elixir 1.12 bug on single atom ASTs
- Handle atoms prefixed with `Elixir.` properly
- Fix inspect for quoted atoms

## v0.1.0 (2021-09-19)

- Initial release
