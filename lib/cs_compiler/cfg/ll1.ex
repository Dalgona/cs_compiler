defmodule CSCompiler.CFG.LL1 do
  alias CSCompiler.CFG

  @type nonterminal :: CFG.nonterminal()
  @type terminal :: CFG.terminal()
  @type symbol :: CFG.symbol()
  @type follower :: terminal() | :end
  @type prod :: CFG.prod()
  @type set :: MapSet.t()
  @type set(type) :: MapSet.t(type)

  @type first_table :: %{optional(nonterminal()) => set(terminal())}
  @type follow_table :: %{optional(nonterminal()) => set(follower())}

  @spec ll1_test(CFG.t()) :: boolean()
  def ll1_test(cfg) do
    vn_e = CFG.nullables(cfg)
    first = build_first(cfg)
    follow = build_follow(cfg, first, vn_e)

    ll1_test(cfg, first, follow)
  end

  @spec ll1_test(CFG.t(), first_table(), follow_table()) :: boolean()
  def ll1_test({_vn, _vt, p, _s}, first, follow) do
    p
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Stream.filter(fn {_lhs, rhs_list} -> length(rhs_list) > 1 end)
    |> Stream.map(fn {lhs, rhs_list} ->
      [x | xs] =
        Enum.map(rhs_list, fn
          [nil] -> follow[lhs]
          rhs -> get_first(rhs, first)
        end)

      List.foldl(xs, x, &MapSet.intersection/2)
    end)
    |> Enum.all?(&Enum.empty?/1)
  end

  @spec build_first(CFG.t()) :: first_table()
  def build_first({_vn, _vt, p, _s}) do
    table = for {lhs, _} <- p, into: %{}, do: {lhs, MapSet.new()}

    table =
      Enum.reduce(p, table, fn
        {lhs, [nil]}, acc ->
          %{acc | lhs => MapSet.put(acc[lhs], nil)}

        {lhs, [terminal | _rest]}, acc when not is_atom(terminal) ->
          %{acc | lhs => MapSet.put(acc[lhs], terminal)}

        _, acc ->
          acc
      end)

    do_build_first(table, %{}, p)
  end

  @spec do_build_first(first_table(), first_table(), [prod()]) :: first_table()
  defp do_build_first(table, table_old, p)
  defp do_build_first(table, table, _p), do: table

  defp do_build_first(table, _table_old, p) do
    new_table =
      Enum.reduce(p, table, fn
        {_lhs, [nil]}, acc ->
          acc

        {lhs, rhs}, acc ->
          %{acc | lhs => MapSet.union(acc[lhs], get_first(rhs, acc))}
      end)

    do_build_first(new_table, table, p)
  end

  @spec get_first(list() | symbol(), first_table()) :: set(terminal())
  def get_first(symbol_or_sentential_form, table)

  def get_first([sym | syms], table) do
    [sym | syms]
    |> Enum.map(&get_first(&1, table))
    |> ring_sum()
  end

  def get_first(x, table) when is_atom(x) and not is_nil(x) do
    table[x] || MapSet.new()
  end

  def get_first(a, _table), do: MapSet.new([a])

  @spec build_follow(CFG.t(), first_table(), set(nonterminal())) :: follow_table()
  def build_follow({_vn, _vt, p, s}, first, vn_e) do
    table = for {lhs, _} <- p, into: %{}, do: {lhs, MapSet.new()}
    table = %{table | s => MapSet.new([:end])}

    table =
      p
      |> Enum.map(fn {_lhs, rhs} -> follow_rule_1([nil | rhs], []) end)
      |> List.flatten()
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Map.new(fn {k, v} ->
        {k, v |> List.flatten() |> Enum.uniq() |> get_first(first)}
      end)
      |> Map.merge(table, fn _k, v1, v2 ->
        v1
        |> MapSet.delete(nil)
        |> MapSet.union(v2)
      end)

    do_build_follow(table, %{}, p, vn_e)
  end

  @spec do_build_follow(follow_table(), follow_table(), [prod()], set(nonterminal())) ::
          follow_table()
  defp do_build_follow(table, table_old, p, vn_e)
  defp do_build_follow(table, table, _p, _vn_e), do: table

  defp do_build_follow(table, _table_old, p, vn_e) do
    targets = follow_rule_2(p) ++ follow_rule_3(p, vn_e)

    new_table =
      Enum.reduce(targets, table, fn {b, a}, acc ->
        %{acc | b => MapSet.union(acc[b], acc[a])}
      end)

    do_build_follow(new_table, table, p, vn_e)
  end

  @spec follow_rule_1([symbol()], [[symbol()]]) :: [{nonterminal(), [symbol()]}]
  defp follow_rule_1(sentential_form, acc)
  defp follow_rule_1([], acc), do: acc

  defp follow_rule_1([_a, x, b | bs], acc) when is_atom(x) and not is_nil(b) do
    follow_rule_1([x, b | bs], [{x, [b | bs]} | acc])
  end

  defp follow_rule_1([_a | as], acc) do
    follow_rule_1(as, acc)
  end

  @spec follow_rule_2([prod()]) :: {nonterminal(), nonterminal()}
  defp follow_rule_2(p) do
    p
    |> Stream.map(fn {lhs, rhs} ->
      {rhs |> Enum.reverse() |> List.first(), lhs}
    end)
    |> Enum.filter(fn {b, a} ->
      is_atom(b) and not is_nil(b) and b != a
    end)
  end

  @spec follow_rule_3([prod()], set(nonterminal())) :: {nonterminal(), nonterminal()}
  defp follow_rule_3(p, vn_e) do
    p
    |> Stream.map(fn {lhs, rhs} ->
      target =
        [nil | rhs]
        |> follow_rule_1([])
        |> Enum.filter(fn {_lhs, rhs} -> Enum.all?(rhs, &(&1 in vn_e)) end)

      {lhs, target}
    end)
    |> Stream.reject(fn {_lhs, rhs} -> Enum.empty?(rhs) end)
    |> Enum.map(fn {a, bs} -> Enum.map(bs, fn {b, _} -> {b, a} end) end)
    |> List.flatten()
    |> Enum.uniq()
  end

  @spec ring_sum([set()]) :: set()
  def ring_sum([set | sets]) do
    do_ring_sum(sets, set)
  end

  @spec ring_sum(set(), set()) :: set()
  def ring_sum(set1, set2) do
    if MapSet.member?(set1, nil) do
      set1
      |> MapSet.delete(nil)
      |> MapSet.union(set2)
    else
      set1
    end
  end

  @spec do_ring_sum([set()], set()) :: set()
  defp do_ring_sum(sets, acc)
  defp do_ring_sum([], acc), do: acc

  defp do_ring_sum([set | sets], acc) do
    if MapSet.member?(acc, nil) do
      new_acc =
        acc
        |> MapSet.delete(nil)
        |> MapSet.union(set)

      do_ring_sum(sets, new_acc)
    else
      acc
    end
  end
end
