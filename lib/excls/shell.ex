defmodule ExCLS.Shell.Context do
  @moduledoc false
  @enforce_keys [:behaviour, :behaviour_state, :history]
  defstruct @enforce_keys ++ [scroll: false, cursor: 0, line: ""]

  @type t :: %__MODULE__{
          behaviour: ExCLS.t(),
          behaviour_state: ExCLS.state(),
          scroll: boolean(),
          history: ExCLS.History.t(),
          cursor: non_neg_integer(),
          line: String.t()
        }

  @type state :: :init | :edit
  @type fsm_res :: {:stop, exit_code :: non_neg_integer()} | {state(), t()}
end

defmodule ExCLS.Shell do
  @moduledoc """
  Shell runner.
  """
  alias ExCLS.History
  alias ExCLS.Shell.Context
  alias ExCLS.Shell.Edit
  alias ExCLS.TTY

  @type opts :: [
          {:history_limit, non_neg_integer()}
        ]

  @spec run(ExCLS.t(), opts()) :: no_return()
  def run(behaviour, opts \\ []) do
    TTY.start()

    ctx = %Context{
      behaviour: behaviour,
      behaviour_state: behaviour.init(),
      history: History.init(Keyword.get(opts, :history_limit, 0))
    }

    if function_exported?(behaviour, :intro, 0) do
      TTY.put_chars([behaviour.intro(), "\r\n"])
    end

    loop(:init, ctx)
  end

  @spec loop(Context.state(), Context.t()) :: no_return()
  defp loop(state, %Context{} = ctx) do
    case fsm(state, ctx) do
      {:stop, exit_code} -> System.halt(exit_code)
      {next_state, ctx} -> loop(next_state, ctx)
    end
  end

  @spec fsm(Context.state(), Context.t()) :: Context.fsm_res()
  defp fsm(:init, %Context{} = ctx) do
    ctx = Edit.prompt(ctx)

    {:edit, ctx}
  end

  defp fsm(:edit, %Context{} = ctx) do
    key = TTY.receive()
    Edit.key(key, ctx)
  end
end

defmodule ExCLS.Shell.Edit do
  @moduledoc false

  alias ExCLS.History
  alias ExCLS.Shell.Context
  alias ExCLS.TTY
  alias ExCLS.TTY.Key

  require Key

  @spec prompt(Context.t()) :: Context.t()
  def prompt(ctx) do
    prompt = ctx.behaviour.prompt(ctx.behaviour_state)
    TTY.put_chars(prompt)

    %{ctx | line: "", cursor: 0}
  end

  @spec key(String.t(), Context.t()) :: Context.fsm_res()
  def key(key, %Context{scroll: false} = ctx) when key in [Key.up(), Key.down()] do
    history = History.cursor_start(ctx.history, ctx.line)
    ctx = %{ctx | history: history, scroll: true}
    key(key, ctx)
  end

  def key(key, %Context{scroll: true} = ctx) when key in [Key.up(), Key.down()] do
    {line, history} =
      case key do
        Key.up() -> History.cursor_backward(ctx.history)
        Key.down() -> History.cursor_forward(ctx.history)
      end

    ctx = rewrite_line(line, String.length(line), ctx)

    if history == :reset do
      history = History.cursor_reset(ctx.history)

      {:edit, %{ctx | history: history, scroll: false}}
    else
      {:edit, %{ctx | history: history}}
    end
  end

  def key(Key.tab(), %Context{} = ctx) do
    if function_exported?(ctx.behaviour, :autocomplete, 3) do
      case ctx.behaviour.autocomplete(ctx.line, ctx.cursor, ctx.behaviour_state) do
        {:done, line, cursor, next_behaviour_state} ->
          ctx = rewrite_line(line, cursor, ctx)

          {:edit, %{ctx | behaviour_state: next_behaviour_state}}

        {:suggest, line, cursor, options, next_behaviour_state} ->
          ctx = %{ctx | behaviour_state: next_behaviour_state}

          options = ["\r\n", Enum.intersperse(options, " "), "\r\n\n"]
          TTY.put_chars(options)
          ctx = prompt(ctx)
          ctx = rewrite_line(line, cursor, ctx)

          {:edit, ctx}
      end
    else
      {:edit, ctx}
    end
  end

  def key(key, %Context{scroll: true} = ctx) do
    history = History.cursor_reset(ctx.history)
    ctx = %{ctx | history: history, scroll: false}
    key(key, ctx)
  end

  def key(Key.enter(), %Context{} = ctx) do
    line = String.trim(ctx.line)
    history = History.append(ctx.history, line)

    case ctx.behaviour.command(line, ctx.behaviour_state) do
      {:ok, command_output, next_behaviour_state} ->
        TTY.put_chars(["\r\n", command_output, "\r\n"])
        ctx = %{ctx | history: history, behaviour_state: next_behaviour_state}
        ctx = prompt(ctx)

        {:edit, ctx}

      {:stop, command_output, exit_code} ->
        TTY.put_chars(["\r\n", command_output, "\r\n"])

        {:stop, exit_code}
    end
  end

  def key(Key.left(), %Context{} = ctx) do
    cursor =
      if cursor_start_of_line?(ctx) do
        ctx.cursor
      else
        TTY.move_rel(-1)
        ctx.cursor - 1
      end

    {:edit, %{ctx | cursor: cursor}}
  end

  def key(Key.right(), %Context{} = ctx) do
    cursor =
      if cursor_end_of_line?(ctx) do
        ctx.cursor
      else
        TTY.move_rel(1)
        ctx.cursor + 1
      end

    {:edit, %{ctx | cursor: cursor}}
  end

  def key(Key.home(), %Context{} = ctx) do
    TTY.move_rel(-ctx.cursor)

    {:edit, %{ctx | cursor: 0}}
  end

  def key(Key.end_(), %Context{} = ctx) do
    line_length = String.length(ctx.line)
    TTY.move_rel(line_length - ctx.cursor)

    {:edit, %{ctx | cursor: line_length}}
  end

  def key(Key.backspace(), %Context{} = ctx) do
    if cursor_start_of_line?(ctx) do
      {:edit, ctx}
    else
      TTY.delete_chars(-1)
      {pre, post} = String.split_at(ctx.line, ctx.cursor)
      pre = String.slice(pre, 0..-2)

      {:edit, %{ctx | cursor: ctx.cursor - 1, line: pre <> post}}
    end
  end

  def key(Key.delete(), %Context{} = ctx) do
    if cursor_end_of_line?(ctx) do
      {:edit, ctx}
    else
      TTY.delete_chars(1)
      {pre, post} = String.split_at(ctx.line, ctx.cursor)
      post = String.slice(post, 1..-1)

      {:edit, %{ctx | line: pre <> post}}
    end
  end

  def key(key, %Context{} = ctx) do
    if String.length(key) == 1 and String.printable?(key) do
      if cursor_end_of_line?(ctx) do
        TTY.put_chars(key)

        {:edit, %{ctx | cursor: ctx.cursor + 1, line: ctx.line <> key}}
      else
        TTY.insert_chars(key)
        {pre, post} = String.split_at(ctx.line, ctx.cursor)

        {:edit, %{ctx | cursor: ctx.cursor + 1, line: pre <> key <> post}}
      end
    else
      TTY.put_chars(["\r\n", "Not handled ctrl/escape key: ", inspect(key), "\r\n"])

      prompt(ctx)
      TTY.put_chars(ctx.line)
      TTY.move_rel(-(String.length(ctx.line) - ctx.cursor))

      {:edit, ctx}
    end
  end

  @spec cursor_end_of_line?(Context.t()) :: boolean()
  defp cursor_end_of_line?(%Context{} = ctx) do
    ctx.cursor == String.length(ctx.line)
  end

  @spec cursor_start_of_line?(Context.t()) :: boolean()
  defp cursor_start_of_line?(%Context{} = ctx) do
    ctx.cursor == 0
  end

  @spec rewrite_line(String.t(), non_neg_integer(), Context.t()) :: Context.t()
  defp rewrite_line(line, cursor, %Context{} = ctx) do
    TTY.delete_chars(String.length(ctx.line) - ctx.cursor)
    TTY.delete_chars(-ctx.cursor)
    TTY.put_chars(line)
    TTY.move_rel(-(String.length(line) - cursor))

    %{ctx | line: line, cursor: cursor}
  end
end
