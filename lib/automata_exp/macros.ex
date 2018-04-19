defmodule AutomataExp.Macros do
  # Macros for DFA

  defmacro dfa_fn(do: clauses) do
    converted_clauses =
      Enum.map(clauses, fn {:->, _, [[state, char_cls], next_state]} ->
        make_clause(state, char_cls, next_state)
      end)

    nil_clause =
      quote do
        _, _ -> nil
      end

    {:fn, [], List.flatten([converted_clauses | nil_clause])}
  end

  defp make_clause(state, char_cls, next_state)

  defp make_clause(state, char, next_state) when is_integer(char) do
    quote do
      unquote(state), unquote(char) -> unquote(next_state)
    end
  end

  defp make_clause(state, {:.., _, [_, _]} = range, next_state) do
    quote do
      unquote(state), x when x in unquote(range) -> unquote(next_state)
    end
  end

  defp make_clause(state, [char], next_state) when is_integer(char) do
    quote do
      unquote(state), unquote(char) -> unquote(next_state)
    end
  end

  defp make_clause(state, char_cls, next_state) when is_list(char_cls) do
    [cmp | cmps] = Enum.map(char_cls, &to_cond/1)
    conds =
      Enum.reduce(cmps, cmp, fn x, acc ->
        quote(do: unquote(acc) or unquote(x))
      end)

    quote do
      unquote(state), x when unquote(conds) -> unquote(next_state)
    end
  end

  defp to_cond(expr)

  defp to_cond(char) when is_integer(char) do
    quote do: x == unquote(char)
  end

  defp to_cond(charlist) when is_list(charlist) do
    quote do: x in unquote(charlist)
  end

  defp to_cond({:.., _, [_, _]} = range) do
    quote do: x in unquote(range)
  end
end
