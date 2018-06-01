defmodule CSCompiler.CFG.LL1.PredictiveParser do
  alias CSCompiler.CFG
  alias CSCompiler.CFG.LL1

  defstruct [:cfg, :table]

  @type t :: %__MODULE__{
          cfg: CFG.t(),
          table: LL1.ll1_table()
        }

  @type table :: %{
          optional(CFG.nonterminal()) => %{
            optional(LL1.follower()) => CFG.prod()
          }
        }

  @type input_sym :: CFG.terminal() | :end
  @type stack_sym :: CFG.symbol() | :end

  @spec new(CFG.t()) :: t()
  def new(cfg) do
    vn_e = CFG.nullables(cfg)
    first = LL1.build_first(cfg)
    follow = LL1.build_follow(cfg, first, vn_e)
    table = build_table(cfg, first, follow)

    %__MODULE__{
      cfg: cfg,
      table: table
    }
  end

  @spec build_table(CFG.t(), LL1.first_table(), LL1.follow_table()) :: table()
  defp build_table({vn, _vt, p, _s}, first, follow) do
    table = for v <- vn, into: %{}, do: {v, %{}}

    p
    |> Enum.map(fn {lhs, rhs} = prod ->
      first_of_rhs = LL1.get_first(rhs, first)
      follow_of_lhs = follow[lhs]

      temp1 =
        first_of_rhs
        |> Enum.reject(&is_nil/1)
        |> Enum.map(&{lhs, &1, prod})

      temp2 =
        if nil in first_of_rhs do
          Enum.map(follow_of_lhs, &{lhs, &1, prod})
        else
          []
        end

      temp1 ++ temp2
    end)
    |> List.flatten()
    |> Enum.reduce(table, fn {nt, t, prod}, acc ->
      put_in(acc, [nt, t], prod)
    end)
  end

  @spec run([CFG.terminal()], t()) :: any() # TODO
  def run(chars, parser)

  def run(chars, %__MODULE__{cfg: {_, _, _, s}, table: table}) do
    input = Enum.reverse([:end | Enum.reverse(chars)])
    stack = [s, :end]

    do_run(input, stack, table)
  end

  @spec do_run([input_sym()], [stack_sym()], table()) :: any() # TODO
  defp do_run(input, stack, table)

  defp do_run([:end], [:end], _table) do
    :accepted
  end

  defp do_run([x | input], [x | stack], table) do
    do_run(input, stack, table)
  end

  defp do_run([x | input], [tos | stack], table) do
    case get_in(table, [tos, x]) do
      {_lhs, [nil]} -> do_run([x | input], stack, table)
      {_lhs, rhs} -> do_run([x | input], List.flatten([rhs | stack]), table)
      nil -> :error
    end
  end

  defp do_run(_, _, _table) do
    :error
  end
end
