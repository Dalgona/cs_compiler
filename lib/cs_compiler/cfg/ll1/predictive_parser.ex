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
end
