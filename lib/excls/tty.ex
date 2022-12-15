defmodule ExCLS.TTY do
  @moduledoc false

  import Bitwise

  @tty __MODULE__

  @typep idx :: -32_768..32_767
  @typep tty_op ::
           {:put_chars, :unicode, IO.chardata()}
           | {:put_chars_sync, :unicode, IO.chardata(), {from :: pid(), reply :: term()}}
           | {:move_rel, idx()}
           | {:insert_chars, :unicode, IO.chardata()}
           | {:delete_chars, idx()}
           | :beep

  @tty_op_put_chars 0
  @tty_op_move_rel 1
  @tty_op_insert_chars 2
  @tty_op_delete_chars 3
  @tty_op_beep 4

  @erts_ttysl_drv_control_magic_number 0x018B0900
  @tty_ctrl_op_get_winsize 100 + @erts_ttysl_drv_control_magic_number

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
    tty_op({:put_chars, :unicode, chars})
  end

  @spec insert_chars(IO.chardata()) :: :ok
  def insert_chars(chars) do
    tty_op({:insert_chars, :unicode, chars})
  end

  @spec move_rel(idx()) :: :ok
  def move_rel(idx) do
    tty_op({:move_rel, idx})
  end

  @spec delete_chars(idx()) :: :ok
  def delete_chars(idx) do
    tty_op({:delete_chars, idx})
  end

  @spec beep() :: :ok
  def beep do
    tty_op(:beep)
  end

  @spec get_winsize() :: {w :: non_neg_integer(), h :: non_neg_integer()}
  def get_winsize do
    tty_ctrl_op(:get_winsize)
  end

  defp tty_ctrl_op(op) do
    case op do
      :get_winsize ->
        res = :erlang.port_control(tty(), @tty_ctrl_op_get_winsize, [])
        <<w::32-unsigned-integer-native, h::32-unsigned-integer-native>> = :erlang.list_to_binary(res)
        {w, h}
    end
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

  @spec tty_op(tty_op()) :: :ok
  defp tty_op(op) do
    data =
      case op do
        {:put_chars, :unicode, chars} -> [@tty_op_put_chars | chars]
        {:move_rel, count} -> [@tty_op_move_rel | put_int16(count)]
        {:insert_chars, :unicode, chars} -> [@tty_op_insert_chars | chars]
        {:delete_chars, count} -> [@tty_op_delete_chars | put_int16(count)]
        :beep -> [@tty_op_beep]
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
  @moduledoc """
  Ctrl bindings.
  """

  @doc "`CTRL`+`a` moves the cursor to the beginning of the line"
  defmacro a, do: quote(do: <<1>>)
  @doc "`CTRL`+`e` moves the cursor to the end of the line"
  defmacro e, do: quote(do: <<5>>)
  @doc "`CTRL`+`d` delete one character to the right of the cursor"
  defmacro d, do: quote(do: <<4>>)
  @doc "`CTRL`+`←` move the cursor one word left"
  defmacro left, do: quote(do: "\e[1;5D")
  @doc "`CTRL`+`→` move the cursor one word right"
  defmacro right, do: quote(do: "\e[1;5C")
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
