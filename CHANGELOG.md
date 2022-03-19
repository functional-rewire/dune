# Changelog

## Dev

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
