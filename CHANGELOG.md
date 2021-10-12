# Changelog

## Dev

### Bug fixes

- Prevent atom leaks due to `Code.string_to_quoted/2` not respecting
  `static_atoms_encoder`
- Handle Elixir 1.12 bug on single atom ASTs
- Handle atoms prefixed with `Elixir.` properly

## v0.1.0 (2021-09-19)

- Initial release
