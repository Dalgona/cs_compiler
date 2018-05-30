defmodule CSCompiler.CFG do
  @type t :: {
          MapSet.t(nonterminal()),
          MapSet.t(terminal),
          [prod()],
          nonterminal()
        }

  @type nonterminal :: atom()
  @type terminal :: char()
  @type symbol :: nonterminal() | terminal() | nil
  @type prod :: {nonterminal(), symbol()}

  @spec new([nonterminal()], [terminal()], [prod()], nonterminal()) :: t()
  def new(vn, vt, p, s) do
    unless Enum.all?(vn, &is_atom/1) do
      raise ArgumentError, "every nonterminal must be an atom"
    end

    unless Enum.all?(vt, &(&1 >= 0 and &1 <= 0x10FFFF)) do
      raise ArgumentError, "every terminal must be a valid unicode character"
    end

    vn_set = MapSet.new(vn)
    vt_set = MapSet.new(vt)

    unless MapSet.member?(vn_set, s) do
      raise ArgumentError, "'s' must be a member of 'vn'"
    end

    {vn_set, vt_set, p, s}
  end
end
