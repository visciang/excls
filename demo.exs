#!/usr/bin/env -S elixir --erl -noinput

# in mix.exs use:
# escript: [emu_args: "-noinput"],

Mix.install([
  {:excls, path: "."}
])

defmodule DemoShell do
  @version "1.0.0"
  @behaviour ExCLS

  alias ExCLS.Autocomplete

  defmodule State do
    defstruct [:count]
  end

  @impl ExCLS
  def init do
    %State{count: 0}
  end

  @impl ExCLS
  def intro do
    IO.ANSI.format([:bright, "This is a demo Shell!\n"])
  end

  @impl ExCLS
  def prompt(%State{count: count}) do
    pre = [:green, "demo", :reset, :bright, :blue, "("]
    post = [:bright, :blue, ")", :reset, :green, "> "]
    IO.ANSI.format([pre, to_string(count), post])
  end

  @impl ExCLS
  def command(line, %State{} = state) do
    case line do
      "quit" ->
        {:stop, "Bye!", 0}

      "version" ->
        next_state = %{state | count: state.count + 1}
        {:ok, "v#{@version}\n", next_state}

      "" ->
        next_state = %{state | count: state.count}
        {:ok, "", next_state}

      _ ->
        next_state = %{state | count: state.count + 1}
        {:ok, "GOT COMMAND: #{line}\n", next_state}
    end
  end

  @impl ExCLS
  def autocomplete(line, cursor_at, %State{} = state) do
    cmd_opts = %{
      "quit" => [],
      "version" => [],
      "cmd1" => ["--all", "--any", "--verbose"],
      "cmd2" => ["-c"]
    }

    case Autocomplete.scan(cmd_opts, line, cursor_at) do
      {:done, completed_line, cursor_at} ->
        {:done, completed_line, cursor_at, state}

      {:suggest, completed_line, cursor_at, options} ->
        {:suggest, completed_line, cursor_at, options, state}
    end
  end
end

ExCLS.run(DemoShell, history_limit: 10)
