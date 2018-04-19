defmodule AutomataExp.DFA do
  defstruct [
    :states,
    :symbols,
    :transition_fn,
    :initial_state,
    :accepted_states
  ]

  @type t :: %__MODULE__{}
  @type state :: term()
  @type transition_fn :: (state(), integer() -> state() | nil)
  @type hook_fn :: (state(), term(), integer() -> term())
  @type result :: {:accepted | :rejected, term(), charlist()}

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

  @spec run(t(), charlist(), term(), hook_fn()) :: result()
  def run(dfa, chars, acc \\ nil, hook_fn \\ fn _, a, _ -> a end)

  def run(dfa, chars, acc, hook_fn) do
    do_run(dfa, dfa.initial_state, chars, acc, hook_fn)
  end

  @spec do_run(t(), state(), charlist(), term(), hook_fn()) :: result()
  def do_run(dfa, state, chars, acc, hook_fn)

  def do_run(dfa, state, [], acc, _hook_fn) do
    if MapSet.member?(dfa.accepted_states, state) do
      {:accepted, acc, []}
    else
      {:rejected, acc, []}
    end
  end

  def do_run(dfa, state, [char | chars], acc, hook_fn) do
    case dfa.transition_fn.(state, char) do
      nil ->
        {:rejected, acc, [char | chars]}

      new_state ->
        do_run(dfa, new_state, chars, hook_fn.(new_state, acc, char), hook_fn)
    end
  end
end
