defmodule ExCLS.History do
  @moduledoc false

  defstruct limit: nil, line: nil, size: 0, q1: :queue.new(), q2: :queue.new()

  @opaque t :: %__MODULE__{
            limit: nil | non_neg_integer(),
            line: nil | String.t(),
            size: non_neg_integer(),
            q1: :queue.queue(String.t()),
            q2: :queue.queue(String.t())
          }

  @type cursor_res :: {item :: String.t(), :reset | t()}

  @spec init(non_neg_integer() | :infinity) :: t()
  def init(limit) do
    %__MODULE__{limit: limit}
  end

  @spec append(t(), item :: String.t()) :: t()
  def append(%__MODULE__{line: line}, _entry) when line != nil do
    raise "Cannot append item to history while scrolling"
  end

  def append(%__MODULE__{limit: 0} = state, _entry) do
    # limit: 0  -->  history "disabled"
    state
  end

  def append(%__MODULE__{} = state, "") do
    # do not track empty lines
    state
  end

  def append(%__MODULE__{} = state, item) do
    {q1, size} =
      if state.size == state.limit do
        {:queue.drop(state.q1), state.size - 1}
      else
        {state.q1, state.size}
      end

    if :queue.peek_r(q1) == {:value, item} do
      # do not track an item "more than once in a row"
      state
    else
      %{state | q1: :queue.in(item, q1), size: size + 1}
    end
  end

  @spec cursor_start(t(), String.t()) :: t()
  def cursor_start(%__MODULE__{} = state, line) do
    %{state | line: line}
  end

  @spec cursor_reset(t()) :: t()
  def cursor_reset(%__MODULE__{} = state) do
    q1 = :queue.join(state.q1, :queue.reverse(state.q2))

    %{state | line: nil, q1: q1, q2: :queue.new()}
  end

  @spec cursor_backward(t()) :: cursor_res()
  def cursor_backward(%__MODULE__{} = state) do
    case :queue.out_r(state.q1) do
      {:empty, _} ->
        case :queue.peek_r(state.q2) do
          :empty -> {state.line, :reset}
          {:value, item} -> {item, state}
        end

      {{:value, item}, q1} ->
        q2 = :queue.in(item, state.q2)

        {item, %{state | q1: q1, q2: q2}}
    end
  end

  @spec cursor_forward(t()) :: cursor_res()
  def cursor_forward(%__MODULE__{} = state) do
    case :queue.out_r(state.q2) do
      {:empty, _} ->
        {state.line, :reset}

      {{:value, item}, q2} ->
        q1 = :queue.in(item, state.q1)
        state = %{state | q1: q1, q2: q2}

        case :queue.peek_r(q2) do
          :empty -> {state.line, :reset}
          {:value, item} -> {item, state}
        end
    end
  end
end
