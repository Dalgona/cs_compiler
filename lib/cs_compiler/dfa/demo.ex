defmodule CSCompiler.DFA.Demo do
  @moduledoc """
  Provides some demo functions of automata.

  Source codes are available on
  [GitHub](https://github.com/Dalgona/cs_compiler).
  """

  require CSCompiler.DFA.Macros
  import CSCompiler.DFA.Macros
  alias CSCompiler.DFA

  @doc """
  Checks if the given charlist is a string of `0`s and `1`s where the number
  of `1`s is even.

  If the number of `1`s is even, the automaton accepts the input.

  ## Examples

      iex> check_parity('0000')
      {:accepted, nil, []}

      iex> check_parity('0101')
      {:accepted, nil, []}

      iex> check_parity('1101')
      {:rejected, nil, []}
  """
  @spec check_parity(charlist()) :: any()
  def check_parity(chars) do
    d = dfa_fn do
      :even, ?0 -> :even
      :even, ?1 -> :odd
      :odd, ?0 -> :odd
      :odd, ?1 -> :even
    end

    dfa = DFA.new([:even, :odd], '01', d, :even, [:even])

    DFA.run(dfa, chars)
  end

  @doc """
  Recognizes an identifier name.

  In order for the automaton to accept the input, it must follow these rules:

  * The first character must be a lowercase letter (`a-z`)
    or an underscore (`_`).
  * The rest of characters can be a mixture of lowercase letters,
    an underscore, and decimal digits (`0-9`).

  ## Examples

      iex> recognize_identifier('a')
      {:accepted, "a", []}

      iex> recognize_identifier('_')
      {:accepted, "_", []}

      iex> recognize_identifier('to_string')
      {:accepted, "to_string", []}

      iex> recognize_identifier('__callback')
      {:accepted, "__callback", []}

      iex> recognize_identifier('99_bottles_of_beer')
      {:rejected, "", '99_bottles_of_beer'}
  """
  @spec recognize_identifier(charlist()) :: any()
  def recognize_identifier(chars) do
    d = dfa_fn do
      :first, [?_, ?a..?z] -> :rest
      :rest, [?_, ?a..?z, ?0..?9] -> :rest
    end

    dfa = DFA.new(
      [:first, :rest],
      '_abcdefghijklmnopqrstuvwxyz0123456789',
      d,
      :first,
      [:rest]
    )

    DFA.run(dfa, chars, "", fn _, acc, char -> acc <> <<char::utf8>> end)
  end

  @doc """
  Recognizes an integer literal and returns its value.

  See the examples below to see which formats are accepted.

  ## Examples

      # Zero
      iex> recognize_integer('0')
      {:accepted, 0, []}

      # Decimal
      iex> recognize_integer('1234')
      {:accepted, 1234, []}

      # Octal
      iex> recognize_integer('0755')
      {:accepted, 493, []}

      # Invalid octal
      iex> recognize_integer('0493')
      {:rejected, 4, '93'}

      # Prefix for hexadecimal integer (invalid)
      iex> recognize_integer('0x')
      {:rejected, 0, []}

      # Hexadecimal (in lowercase)
      iex> recognize_integer('0xac00')
      {:accepted, 44032, []}

      # Hexadecimal (in mixed-case)
      iex> recognize_integer('0XD7a3')
      {:accepted, 55203, []}

      # Invalid hexadecimal
      iex> recognize_integer('0x12Z9')
      {:rejected, 18, 'Z9'}
  """
  @spec recognize_integer(charlist()) :: any()
  def recognize_integer(chars) do
    d = dfa_fn do
      :start, [?1..?9] -> :dec
      :start, ?0 -> :zero
      :dec,   [?0..?9] -> :dec
      :zero,  [?0..?7] -> :oct
      :oct,   [?0..?7] -> :oct
      :zero,  'Xx' -> :x
      :x,     [?0..?9, ?A..?F, ?a..?f] -> :hex
      :hex,   [?0..?9, ?A..?F, ?a..?f] -> :hex
    end

    dfa = DFA.new(
      [:start, :dec, :zero, :oct, :x, :hex],
      '0123456789ABCDEFabcdefXx',
      d,
      :start,
      [:dec, :zero, :oct, :hex]
    )

    DFA.run(dfa, chars, 0, &build_integer/3)
  end

  @spec build_integer(DFA.state(), integer(), integer()) :: integer()
  defp build_integer(state, acc, char)
  defp build_integer(:dec, acc, char), do: acc * 10 + (char - ?0)
  defp build_integer(:oct, acc, char), do: acc * 8 + (char - ?0)
  defp build_integer(:hex, acc, char), do: acc * 16 + hex2num(char)
  defp build_integer(_state, acc, _char), do: acc

  @spec multiple_tokens(charlist()) :: any()
  def multiple_tokens(chars) do
    d = dfa_fn do
      :ws,   ?\s -> :ws
      :ws,   [?1..?9] -> :dec
      :dec,  [?1..?9] -> :dec
      :ws,   ?0 -> :zero
      :zero, [?0..?7] -> :oct
      :oct,  [?0..?7] -> :oct
      :zero, 'Xx' -> :x
      :x,    [?0..?9, ?A..?F, ?a..?f] -> :hex
      :hex,  [?0..?9, ?A..?F, ?a..?f] -> :hex
      :ws,   ?( -> :lparen
      :ws,   ?) -> :rparen
      :ws,   ?+ -> :plus
      :ws,   ?* -> :asterisk
    end

    dfa = DFA.new(
      [:ws, :dec, :zero, :oct, :x, :hex, :lparen, :rparen, :plus, :asterisk],
      ' 0123456789ABCDEFabcdefXx()*+',
      d,
      :ws,
      [:dec, :zero, :oct, :hex, :lparen, :rparen, :plus, :asterisk]
    )

    do_analysis(dfa, chars, [])
  end

  @spec do_analysis(DFA.t(), charlist(), [term()]) :: {:ok, [term()]} | {:error, charlist()}
  defp do_analysis(dfa, chars, tokens)

  defp do_analysis(_dfa, [], tokens) do
    {:ok, Enum.reverse(tokens)}
  end

  defp do_analysis(dfa, chars, tokens) do
    case DFA.run_multiple(dfa, chars, nil, &mt_hook/3) do
      {:accepted, token, rest_chars} ->
        do_analysis(dfa, rest_chars, [token | tokens])

      {:rejected, _, rest_chars} ->
        {:error, rest_chars}
    end
  end

  @spec mt_hook(DFA.state(), term(), char()) :: term()
  defp mt_hook(state, acc, char)

  defp mt_hook(:dec, {:int_const, val}, char), do: {:int_const, val * 10 + (char - ?0)}
  defp mt_hook(:dec, nil, char), do: {:int_const, char - ?0}
  defp mt_hook(:zero, nil, ?0), do: {:int_const, 0}
  defp mt_hook(:oct, {:int_const, val}, char), do: {:int_const, val * 8 + (char - ?0)}
  defp mt_hook(:oct, nil, char), do: {:int_const, char - ?0}
  defp mt_hook(:hex, {:int_const, val}, char), do: {:int_const, val * 16 + hex2num(char)}
  defp mt_hook(:lparen, nil, ?(), do: {:paren_left, nil}
  defp mt_hook(:rparen, nil, ?)), do: {:paren_right, nil}
  defp mt_hook(:plus, nil, ?+), do: {:plus, nil}
  defp mt_hook(:asterisk, nil, ?*), do: {:asterisk, nil}
  defp mt_hook(_state, acc, _char), do: acc

  @spec hex2num(integer()) :: integer()
  defp hex2num(char) when char in ?0..?9, do: char - ?0
  defp hex2num(char) when char in ?A..?F, do: char - ?A + 10
  defp hex2num(char) when char in ?a..?f, do: char - ?a + 10
end
