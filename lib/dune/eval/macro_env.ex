defmodule Dune.Eval.MacroEnv do
  @moduledoc false

  # Recommended way to generate a Macro.Env struct
  # https://hexdocs.pm/elixir/main/Macro.Env.html
  def make_env do
    import Dune.Shims.Kernel, only: [safe_sigil_w: 3, safe_sigil_W: 3], warn: false

    %Macro.Env{__ENV__ | file: "nofile", module: nil, function: nil, line: 1}
  end
end
