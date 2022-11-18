#!/usr/bin/env -S elixir --erl -noinput

defmodule CLI do
  require Logger

  import Bitwise

  @opaque continuation :: tuple()
  @type edit_request ::
          {:put_chars, :unicode, charlist()}
          | {:put_chars_sync, :unicode, charlist(), {from :: pid(), reply :: term()}}
          | {:move_rel, -32768..32767}
          | {:insert_chars, :unicode, charlist()}
          | {:delete_chars, -32768..32767}
          | :beep

  # TODO any()
  @type edit_action ::
          {:done, line :: charlist(), rest :: charlist(), [edit_request()]}
          | {:more_chars, continuation(), [edit_request()]}
          | {:blink, continuation(), [edit_request()]}
          | {:undefined, char :: any(), rest :: charlist(), continuation(), [edit_request()]}

  @type line_num :: non_neg_integer()

  defmodule EditStart do
    @enforce_keys [:idx]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            idx: non_neg_integer()
          }
  end

  defmodule EditLine do
    @enforce_keys [:idx, :action]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            idx: non_neg_integer(),
            action: CLI.edit_action()
          }
  end

  @spec run :: no_return()
  def run do
    Application.put_env(:elixir, :ansi_enabled, true)
    tty_port = Port.open({:spawn, 'tty_sl -c -e'}, [])

    :edlin.init()

    loop(tty_port, %EditStart{idx: 0})
  end

  @spec loop(port(), EditStart.t()) :: no_return()
  defp loop(tty_port, %EditStart{idx: idx}) do
    action = :edlin.start(prompt(idx))

    loop(tty_port, %EditLine{idx: idx, action: action})
  end

  @spec loop(port(), EditLine.t()) :: no_return()
  defp loop(tty_port, %EditLine{idx: idx, action: action}) do
    case process_edit_line_requests(tty_port, action) do
      :done ->
        loop(tty_port, %EditStart{idx: idx + 1})

      {:cont, continuation} ->
        receive do
          {^tty_port, {:data, keyboard_input}} ->
            action = :edlin.edit_line(keyboard_input, continuation)

            loop(tty_port, %EditLine{idx: idx, action: action})

          # TODO
          other ->
            Logger.warning(inspect(other))
        end
    end
  end

  @spec process_edit_line_requests(port(), edit_action()) :: :done | {:cont, continuation()}
  defp process_edit_line_requests(tty_port, action) do
    case action do
      {:done, _line, _rest, requests} ->
        tty_requests(tty_port, requests)
        :done

      {:more_chars, continuation, requests} ->
        tty_requests(tty_port, requests)
        {:cont, continuation}

      {:blink, continuation, _requests} ->
        IO.inspect(action)
        {:cont, continuation}

      {:undefined, _char, _rest, continuation, _requests} ->
        IO.inspect(action)
        {:cont, continuation}

      {:expand, _char, _rest, continuation, _requests} ->
        IO.inspect(action)
        {:cont, continuation}
    end
  end

  @spec tty_requests(port(), [edit_request()]) :: :ok
  defp tty_requests(tty_port, requests) do
    Enum.each(requests, fn request ->
      tty_command(tty_port, request)
    end)
  end

  @spec tty_command(port(), edit_request()) :: :ok
  defp tty_command(tty_port, request) do
    data =
      case request do
        {:put_chars, :unicode, chars} ->
          [0 | chars]

        {:move_rel, count} ->
          [1 | put_int16(count)]

        {:insert_chars, :unicode, chars} ->
          [2 | chars]

        {:delete_chars, count} ->
          [3 | put_int16(count)]

        :beep ->
          [4]

          # TODO
          # {:put_chars_sync, :unicode, chars, reply} ->
          #   {[5 | chars], reply}
      end

    true = Port.command(tty_port, data)

    :ok
  end

  @spec prompt(line_num()) :: charlist()
  defp prompt(idx) do
    'cli(#{idx})> '
  end

  @spec put_int16(integer()) :: [integer()]
  defp put_int16(num) do
    [num |> bsr(8) |> band(0xFF), num |> band(0xFF)]
  end
end

CLI.run()
