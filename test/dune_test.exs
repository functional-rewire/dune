defmodule DuneTest do
  use ExUnit.Case, async: true

  # TODO remove then dropping support for 1.15
  doctest Dune, tags: [lts_only: true]
end
