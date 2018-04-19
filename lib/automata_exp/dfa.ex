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

  @spec run(t(), charlist()) :: any() # TODO (the same as do_run/3)
  def run(dfa, chars) do
    do_run(dfa, dfa.initial_state, chars)
  end

  @spec do_run(t(), state(), charlist()) :: any() # TODO
  def do_run(dfa, state, chars)

  def do_run(dfa, state, []) do
    MapSet.member?(dfa.accepted_states, state) && :accepted || :rejected
  end

  def do_run(dfa, state, [char | chars]) do
    case dfa.transition_fn.(state, char) do
      nil ->
        :rejected

      next_state ->
        do_run(dfa, next_state, chars)
    end
  end
end
