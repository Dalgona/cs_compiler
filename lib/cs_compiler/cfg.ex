defmodule CSCompiler.CFG do
  @type t :: {
          set(nonterminal()),
          set(terminal),
          [prod()],
          nonterminal()
        }

  @type nonterminal :: atom()
  @type terminal :: char()
  @type symbol :: nonterminal() | terminal() | nil
  @type follower :: terminal | :end
  @type prod :: {nonterminal(), symbol()}
  @type set :: MapSet.t()
  @type set(type) :: MapSet.t(type)

  @type first_table :: %{optional(nonterminal()) => set(terminal())}
  @type follow_table :: %{optional(nonterminal()) => set(follower())}

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

    accepted_rhs =
      [nil]
      |> MapSet.new()
      |> MapSet.union(vn_set)
      |> MapSet.union(vt_set)

    Enum.each(p, fn {lhs, rhs} ->
      unless MapSet.member?(vn_set, lhs) do
        raise ArgumentError, "#{lhs} is not a member of vn"
      end

      Enum.each(rhs, fn sym ->
        unless MapSet.member?(accepted_rhs, sym) do
          raise ArgumentError, "invalid symbol #{sym} in production rules"
        end
      end)
    end)

    unless MapSet.member?(vn_set, s) do
      raise ArgumentError, "'s' must be a member of 'vn'"
    end

    {vn_set, vt_set, p, s}
  end

  @spec nullables(t()) :: set(nonterminal())
  def nullables({_vn, _vt, p, _s}) do
    vn_e = for {lhs, [nil]} <- p, into: MapSet.new(), do: lhs
    update_nullables(vn_e, MapSet.new(), p)
  end

  @spec update_nullables(set(nonterminal()), set(nonterminal()), [prod]) :: set(nonterminal())
  defp update_nullables(vn_e, vn_e_old, p)
  defp update_nullables(vn_e, vn_e, _p), do: vn_e

  defp update_nullables(vn_e, _vn_e_old, p) do
    tmp =
      for {lhs, rhs} <- p, Enum.all?(rhs, &MapSet.member?(vn_e, &1)), into: MapSet.new(), do: lhs

    update_nullables(MapSet.union(vn_e, tmp), vn_e, p)
  end

  @spec build_first(t()) :: first_table()
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
  defp get_first(symbol_or_sentential_form, table)

  defp get_first([sym | syms], table) do
    [sym | syms]
    |> Enum.map(&get_first(&1, table))
    |> ring_sum()
  end

  defp get_first(a, _table) when not is_atom(a), do: MapSet.new([a])
  defp get_first(x, table), do: table[x] || MapSet.new()

  @spec build_follow(t()) :: follow_table()
  def build_follow({_vn, _vt, p, s} = cfg) do
    first = build_first(cfg)
    vt_e = nullables(cfg)

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

    do_build_follow(table, %{}, p, vt_e)
  end

  @spec do_build_follow(follow_table(), follow_table(), [prod()], set(nonterminal())) ::
          follow_table()
  defp do_build_follow(table, table_old, p, vt_e)
  defp do_build_follow(table, table, _p, _vt_e), do: table

  defp do_build_follow(table, _table_old, p, vt_e) do
    targets = follow_rule_2(p) ++ follow_rule_3(p, vt_e)

    new_table =
      Enum.reduce(targets, table, fn {b, a}, acc ->
        %{acc | b => MapSet.union(acc[b], acc[a])}
      end)

    do_build_follow(new_table, table, p, vt_e)
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
  defp follow_rule_3(p, vt_e) do
    p
    |> Stream.map(fn {lhs, rhs} ->
      target =
        [nil | rhs]
        |> follow_rule_1([])
        |> Enum.filter(fn {_lhs, rhs} -> Enum.all?(rhs, &(&1 in vt_e)) end)

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
