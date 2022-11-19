defmodule ExCLS.TTY do
  @moduledoc false

  import Bitwise

  @tty __MODULE__

  @typep idx :: -32_768..32_767
  @typep request ::
           {:put_chars, :unicode, IO.chardata()}
           | {:put_chars_sync, :unicode, IO.chardata(), {from :: pid(), reply :: term()}}
           | {:move_rel, idx()}
           | {:insert_chars, :unicode, IO.chardata()}
           | {:delete_chars, idx()}
           | :beep

  @spec start :: :ok
  def start do
    unless IO.ANSI.enabled?() do
      raise "ANSI mode not supported or enabled. (ref: '-elixir ansi_enabled true')"
    end

    tty_port = Port.open({:spawn, "tty_sl -c -e"}, [:eof, :binary])
    Process.register(tty_port, @tty)

    :ok
  end

  @spec put_chars(IO.chardata()) :: :ok
  def put_chars(chars) do
    request({:put_chars, :unicode, chars})
  end

  @spec insert_chars(IO.chardata()) :: :ok
  def insert_chars(chars) do
    request({:insert_chars, :unicode, chars})
  end

  @spec move_rel(idx()) :: :ok
  def move_rel(idx) do
    request({:move_rel, idx})
  end

  @spec delete_chars(idx()) :: :ok
  def delete_chars(idx) do
    request({:delete_chars, idx})
  end

  @spec beep() :: :ok
  def beep do
    request(:beep)
  end

  @spec receive() :: String.t()
  def receive do
    tty_port = tty()

    receive do
      {^tty_port, {:data, key}} -> key
      other -> raise "Unknown msg received: #{inspect(other)}"
    end
  end

  @spec tty() :: port()
  defp tty do
    case Process.whereis(@tty) do
      port when is_port(port) -> port
    end
  end

  @spec request(request()) :: :ok
  defp request(request) do
    data =
      case request do
        {:put_chars, :unicode, chars} -> [0 | chars]
        {:move_rel, count} -> [1 | put_int16(count)]
        {:insert_chars, :unicode, chars} -> [2 | chars]
        {:delete_chars, count} -> [3 | put_int16(count)]
        :beep -> [4]
      end

    true = Port.command(tty(), data)

    :ok
  end

  @spec put_int16(integer()) :: [integer()]
  defp put_int16(num) do
    [num |> bsr(8) |> band(0xFF), num |> band(0xFF)]
  end
end

defmodule ExCLS.TTY.Ctrl do
  @moduledoc false

  # https://fishshell.com/docs/current/interactive.html#command-line-editor
  # CTRL+a  (moves the cursor to the beginning of the line)
  #   defmacro a, do: quote(do: <<1>>)
  # CTRL+e  (moves the cursor to the end of the line)
  # CTRL+e  (got to end of line)
  # CTRL+←  (move the cursor one word left)
  # CTRL+→  (move the cursor one word right)
end

defmodule ExCLS.TTY.Key do
  @moduledoc false

  defmacro enter, do: quote(do: "\r")
  defmacro backspace, do: quote(do: "\d")
  defmacro tab, do: quote(do: "\t")
  defmacro up, do: quote(do: "\e[A")
  defmacro down, do: quote(do: "\e[B")
  defmacro right, do: quote(do: "\e[C")
  defmacro left, do: quote(do: "\e[D")
  defmacro delete, do: quote(do: "\e[3~")
  defmacro home, do: quote(do: "\e[H")
  defmacro end_, do: quote(do: "\e[F")
end
