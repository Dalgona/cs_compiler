defmodule CSCompiler.DFA do
  @moduledoc """
  Deterministic Finite Automata (DFA)

  This module defines deterministic finite automata (DFA), which are usually
  used to recognize regular languages.

  Read the documentation for `new/5` to learn how to define an automaton.
  The documentation for `run/4` shows how to make the automaton do some work.
  Also, the following demo functions show typical usages of DFAs:

  * `CSCompiler.Demo.check_parity/1`
  * `CSCompiler.Demo.recognize_identifier/1`
  * `CSCompiler.Demo.recognize_integer/1`
  """

  defstruct [
    :states,
    :symbols,
    :transition_fn,
    :initial_state,
    :accepted_states
  ]

  @type t :: %__MODULE__{
    states: MapSet.t(state()),
    symbols: MapSet.t(integer()),
    transition_fn: transition_fn(),
    initial_state: state(),
    accepted_states: MapSet.t(state())
  }

  @type state :: term()
  @type transition_fn :: (state(), integer() -> state() | nil)
  @type hook_fn :: (state(), term(), integer() -> term())
  @type result :: {:accepted | :rejected, term(), charlist()}

  @doc """
  Creates a new `DFA` struct.

  Use this function to define a deterministic finite automaton. Creating a
  struct directly using `%DFA{}` is not recommended.

  ## Arguments

  * `q`: A set of states a new automaton will have (Q).
  * `s`: A set of terminal symbols accepted by this automaton (Σ).
  * `d`: A transition function (δ). Read further for more information.
  * `q0`: A starting state (q₀ ∈ Q).
  * `f`: A set of accepting states (F ⊆ Q).

  Arguments `q`, `s`, and `f` accept lists, instead of `MapSet`s, to minize
  the verbosity of your code. Those lists are converted into `MapSet`s by this
  function. You can use any Elixir term for each state, but atoms are suitable
  for most of the cases. However, `s` must be a list of characters
  (`charlist`), such as `'01'`, `'abcdefgh'`, etc.

  ## Defining a Transition Function (δ)

  The following rules must be met for each transition function (δ):

  * The function must accept two arguments. The first one is the current state
    of the automaton, and the second one is the current input character.
  * Each function clause must return the next state of the automaton.
  * An extra function clause (`_, _ -> nil`) shall follow the last defined
    clause. This clause takes a role of ∅ (an empty set).

  Here are some examples of transition functions:

  ```
  fn
    :even, ?0 -> :even
    :even, ?1 -> :odd
    :odd, ?0 -> :odd
    :odd, ?1 -> :even
    _, _ -> nil
  end
  ```

  ```
  # You can also use guards to accept a character in a range.
  fn
    :first, x when x in ?a..?z -> :rest
    :rest, x when x in ?a..?z or x in ?0..?9 -> :rest
    _, _ -> nil
  end
  ```

  Most of the time, using guards to specify a range of accepted characters
  is tedious and requires a lot of keystrokes. You can use
  `CSCompiler.Macros.dfa_fn/1` macro to alleviate this problem.

  ```
  # Make sure you import and require CSCompiler.Macros module.

  dfa_fn do
    # Single character
    :q0, ?a -> :q1

    # Single range
    :q1, ?w..?z -> :q2

    # A crazy combination
    :q2, [?p, ?q, '+-*/', ?0..?9] -> :q3
  end
  ```

  The code above is roughly transformed into this:

  ```
  fn
    # Single character
    :q0, ?a -> :q1

    # Single range
    :q1, x when x in ?w..?z -> :q2

    # A crazy combination
    :q2, x when x == ?p or x == ?q or x in '+-*/' or x in ?0..?9 -> :q3

    # This clause is automatically appended.
    _, _ -> nil
  end
  ```
  """
  @spec new([state()], charlist(), transition_fn(), state(), [state()]) :: t()
  def new(q, s, d, q0, f) do
    state_set = MapSet.new(q)
    symbol_set = MapSet.new(s)
    accepted_set = MapSet.new(f)

    unless MapSet.member?(state_set, q0) do
      raise ArgumentError, "q0 must be an element of Q"
    end

    unless MapSet.subset?(accepted_set, state_set) do
      raise ArgumentError, "F must be a subset of Q"
    end

    %__MODULE__{
      states: state_set,
      symbols: symbol_set,
      transition_fn: d,
      initial_state: q0,
      accepted_states: accepted_set
    }
  end

  @doc """
  Runs the given DFA.

  This function makes the given DFA process the input charlist `chars`. The
  automaton will read a character from `chars` and move around the states
  according to the transition function.

  If you additionally specify an accumulator value `acc` and a hook function
  `hook_fn`, The automaton will call the `hook_fn` every time it does a
  transition. `hook_fn` must take three arguments: the new state of the
  automaton, the current accumulator, and a character the automaton just read.
  And it must return the new value of the accumulator. For example, let's say
  that a DFA in state `:foo` moved to state `:bar` by reading a character `a`,
  and the current accumulator value is `100`. Then the hook function will be
  called with arguments `:bar`, `100`, and `?a`.

  ## Return Value

  Values returned by this function are in the form of `{status, acc, rest}`.
  `status` is one of `:accepted` or `:rejected`, and it indicates whether the
  automaton has accepted or rejected the input charlist. `acc` is the final
  value of the accumulator, which usually is meaningful only if `status` is
  `:accepted`. And finally, `rest` is a part of the input charlist which has
  not been read by the automaton before it halted. `rest` must be an empty list
  if `status` is `:accepted`, obviously.
  """
  @spec run(t(), charlist(), term(), hook_fn()) :: result()
  def run(dfa, chars, acc \\ nil, hook_fn \\ fn _, a, _ -> a end)

  def run(dfa, chars, acc, hook_fn) do
    do_run(dfa, dfa.initial_state, chars, acc, hook_fn)
  end

  @spec do_run(t(), state(), charlist(), term(), hook_fn()) :: result()
  defp do_run(dfa, state, chars, acc, hook_fn)

  defp do_run(dfa, state, [], acc, _hook_fn) do
    if MapSet.member?(dfa.accepted_states, state) do
      {:accepted, acc, []}
    else
      {:rejected, acc, []}
    end
  end

  defp do_run(dfa, state, [char | chars], acc, hook_fn) do
    case dfa.transition_fn.(state, char) do
      nil ->
        {:rejected, acc, [char | chars]}

      new_state ->
        do_run(dfa, new_state, chars, hook_fn.(new_state, acc, char), hook_fn)
    end
  end

  @spec run_multiple(t(), charlist(), term(), hook_fn()) :: result()
  def run_multiple(dfa, chars, acc \\ nil, hook_fn \\ fn _, a, _ -> a end)

  def run_multiple(dfa, chars, acc, hook_fn) do
    do_run_multiple(dfa, dfa.initial_state, chars, acc, hook_fn)
  end

  defp do_run_multiple(dfa, state, [], acc, _hook_fn) do
    if MapSet.member?(dfa.accepted_states, state) do
      {:accepted, acc, []}
    else
      {:rejected, acc, []}
    end
  end

  defp do_run_multiple(dfa, state, [char | chars], acc, hook_fn) do
    case dfa.transition_fn.(state, char) do
      nil ->
        if MapSet.member?(dfa.accepted_states, state) do
          {:accepted, acc, [char | chars]}
        else
          {:rejected, acc, [char | chars]}
        end

      new_state ->
        new_acc = hook_fn.(new_state, acc, char)

        do_run_multiple(dfa, new_state, chars, new_acc, hook_fn)
    end
  end
end
