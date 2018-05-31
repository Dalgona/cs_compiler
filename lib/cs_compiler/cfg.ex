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
  @type follower :: terminal | :end
  @type prod :: {nonterminal(), symbol()}

  @type first_table :: %{optional(nonterminal()) => MapSet.t(terminal())}
  @type follow_table :: %{optional(nonterminal()) => MapSet.t(follower())}

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

  @spec nullables(t()) :: MapSet.t(nonterminal())
  def nullables({_vn, _vt, p, _s}) do
    vn_e = for {lhs, [nil]} <- p, into: MapSet.new(), do: lhs
    update_nullables(vn_e, MapSet.new(), p)
  end

  @spec update_nullables(MapSet.t(nonterminal()), MapSet.t(nonterminal()), [prod]) ::
          MapSet.t(nonterminal())
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
          %{acc | lhs => MapSet.union(acc[lhs], get_first(acc, rhs))}
      end)

    do_build_first(new_table, table, p)
  end

  @spec get_first(first_table(), list() | symbol()) :: MapSet.t(terminal())
  defp get_first(table, symbol_or_sentential_form)

  defp get_first(table, [sym | syms]) do
    [sym | syms]
    |> Enum.map(&get_first(table, &1))
    |> ring_sum()
  end

  defp get_first(_table, a) when not is_atom(a), do: MapSet.new([a])
  defp get_first(table, x), do: table[x] || MapSet.new()

  @spec build_follow(t()) :: follow_table()
  def build_follow({_vn, _vt, p, s}) do
    table = for {lhs, _} <- p, into: %{}, do: {lhs, MapSet.new()}
    table = %{table | s => MapSet.new([:end])}

#    table =
#      Enum.reduce(p, table, fn {_lhs, rhs}, acc ->
#        case follow_rule_1([nil | rhs], []) do
#          [] ->
#            acc
#
#          list ->
#            IO.inspect list
#        end
#      end)

    p
    |> Enum.map(fn {_lhs, rhs} -> follow_rule_1([nil | rhs], []) end)
    |> List.flatten()
  end

  @spec follow_rule_1([symbol()], [[symbol()]]) :: any # TODO
  defp follow_rule_1(sentential_form, acc)
  defp follow_rule_1([], acc), do: acc

  defp follow_rule_1([_a, x, b | bs], acc) when is_atom(x) and not is_nil(b) do
    follow_rule_1([x, b | bs], [{x, [b | bs]} | acc])
  end

  defp follow_rule_1([_a | as], acc) do
    follow_rule_1(as, acc)
  end

  @spec ring_sum([MapSet.t()]) :: MapSet.t()
  def ring_sum([set | sets]) do
    do_ring_sum(sets, set)
  end

  @spec ring_sum(MapSet.t(), MapSet.t()) :: MapSet.t()
  def ring_sum(set1, set2) do
    if MapSet.member?(set1, nil) do
      set1
      |> MapSet.delete(nil)
      |> MapSet.union(set2)
    else
      set1
    end
  end

  @spec do_ring_sum([MapSet.t()], MapSet.t()) :: MapSet.t()
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
