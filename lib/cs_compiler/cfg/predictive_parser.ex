defmodule CSCompiler.CFG.PredictiveParser do
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
  @type parse_tree :: {CFG.symbol(), [parse_tree()]}
  @type parse_error :: {:error, [input_sym()]}
  @typep make_tree_result :: {parse_tree(), [input_sym()], [stack_sym()]}

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

  @spec run([CFG.terminal()], t()) :: {:ok, parse_tree()} | parse_error()
  def run(chars, parser)

  def run(chars, %__MODULE__{cfg: {_, _, _, s}, table: table}) do
    input = Enum.reverse([:end | Enum.reverse(chars)])
    stack = [s, :end]

    case make_tree(input, stack, table) do
      {{:node, _, _} = node, [:end], [:end]} ->
        {:ok, node}

      {{:node, _, _}, rest_input, _} ->
        {:error, remove_trailing_end(rest_input)}

      {:error, rest_input} ->
        {:error, remove_trailing_end(rest_input)}
    end
  end

  @spec make_tree([input_sym()], [stack_sym()], table()) :: make_tree_result() | parse_error()
  defp make_tree(input, stack, table)

  defp make_tree([x | input], [x | stack], _table) do
    {{:node, x, []}, input, stack}
  end

  defp make_tree([a | _as] = input, [tos | stack], table) do
    case get_in(table, [tos, a]) do
      nil ->
        {:error, input}

      {lhs, [nil]} ->
        {{:node, lhs, []}, input, stack}

      {lhs, rhs} ->
        expanded = List.flatten([rhs | stack])

        case make_tree_rec(rhs, input, expanded, table, []) do
          {children, rest_input, rest_stack} ->
            {{:node, lhs, children}, rest_input, rest_stack}

          {:error, _} = error ->
            error
        end
    end
  end

  defp make_tree(input, _stack, _table) do
    {:error, input}
  end

  @spec make_tree_rec([CFG.symbol()], [input_sym()], [stack_sym()], table(), [parse_tree()]) ::
          {[parse_tree()], [input_sym()], [stack_sym()]} | parse_error()
  defp make_tree_rec(rhs, input, stack, table, acc)

  defp make_tree_rec([], input, stack, _table, acc) do
    {Enum.reverse(acc), input, stack}
  end

  defp make_tree_rec([_sym | syms], input, stack, table, acc) do
    case make_tree(input, stack, table) do
      {tree, rest_input, rest_stack} ->
        make_tree_rec(syms, rest_input, rest_stack, table, [tree | acc])

      {:error, _} = error ->
        error
    end
  end

  @spec remove_trailing_end([input_sym()]) :: [input_sym()]
  defp remove_trailing_end(input) do
    input
    |> Enum.reverse()
    |> tl()
    |> Enum.reverse()
  end
end
