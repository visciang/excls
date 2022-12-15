defmodule ExCLS.Autocomplete do
  @moduledoc """
  Helper to implement a classic command+args `c:ExCLS.autocomplete/3` callback.
  """

  @typedoc """
  Command + [args] definitions.

  ```elixir
  %{
    "ls" => ["--verbose", "--all"],
    "rm" => ["--force", "--recursive", "-f", "-r"]
  }
  ```
  """
  @type cmd_opts :: %{
          (cmd :: String.t()) => options :: [String.t()]
        }

  @type scan_res ::
          {:suggest, completed_line :: String.t(), cursor_idx :: non_neg_integer(), suggestions :: [String.t()]}
          | {:done, completed_line :: String.t(), cursor_idx :: non_neg_integer()}

  @typep line :: String.t()
  @typep token :: String.t()
  @typep tokens :: [token()]
  @typep current_token :: nil | token()
  @typep current_token_idx :: nil | non_neg_integer()

  @spec scan(cmd_opts(), line(), cursor_at :: non_neg_integer()) :: scan_res()
  def scan(cmd_opts, line, cursor_at) do
    case tokens(line, cursor_at) do
      nil ->
        {:done, line, cursor_at}

      {:ok, [], _current_token, _current_idx} ->
        cmds = Map.keys(cmd_opts)
        {:suggest, line, cursor_at, cmds}

      {:ok, tokens, current_token, current_idx} ->
        case scan_tokens(cmd_opts, tokens, current_token, current_idx) do
          :done -> {:done, line, cursor_at}
          res -> res
        end
    end
  end

  @doc false
  @spec tokens(line(), cursor_at :: non_neg_integer()) :: nil | {:ok, tokens(), current_token(), current_token_idx()}
  def tokens(line, cursor_at) do
    tokens =
      line
      |> String.split(" ", trim: false)
      |> Enum.intersperse(" ")
      |> Enum.reject(&(&1 == ""))

    tokens
    |> Enum.with_index()
    |> Enum.reduce_while(0, fn {token, idx}, len ->
      len = len + String.length(token)

      if len >= cursor_at do
        {:halt, {token, idx}}
      else
        {:cont, len}
      end
    end)
    |> case do
      0 ->
        {:ok, [], nil, nil}

      {token, idx} ->
        {:ok, tokens, token, idx}

      _ ->
        nil
    end
  end

  @spec scan_tokens(cmd_opts(), tokens(), current_token(), current_token_idx()) :: scan_res() | :done
  defp scan_tokens(cmd_opts, tokens, current_token, current_idx) do
    opts =
      case tokens do
        [_cmd] -> Map.keys(cmd_opts)
        [cmd | _] -> Map.get(cmd_opts, cmd, [])
      end

    current_token = String.trim(current_token)

    case filter(opts, current_token) do
      [] ->
        :done

      [match] ->
        {tokens, current_idx} = insert_match(tokens, current_token, current_idx, match)
        line = IO.chardata_to_string(tokens)

        cursor_idx =
          tokens
          |> Enum.take(current_idx + 1)
          |> Enum.map(&String.length/1)
          |> Enum.sum()

        {:done, line, cursor_idx}

      suggestions ->
        common_prefix = common_prefix(suggestions)

        {line, cursor_idx} =
          if common_prefix == "" do
            line = IO.chardata_to_string(tokens)
            cursor_idx = String.length(line)

            {line, cursor_idx}
          else
            {tokens, current_idx} = insert_match(tokens, current_token, current_idx, common_prefix)
            line = IO.chardata_to_string(tokens)

            cursor_idx =
              tokens
              |> Enum.take(current_idx + 1)
              |> Enum.map(&String.length/1)
              |> Enum.sum()

            {line, cursor_idx}
          end

        {:suggest, line, cursor_idx, suggestions}
    end
  end

  @spec insert_match(tokens(), current_token(), current_token_idx(), IO.chardata()) :: {tokens(), non_neg_integer()}
  defp insert_match(tokens, current_token, current_idx, match) do
    if current_token == "" do
      current_idx = current_idx + 1
      {List.insert_at(tokens, current_idx, match), current_idx}
    else
      {List.replace_at(tokens, current_idx, match), current_idx}
    end
  end

  @spec common_prefix(suggestions :: [String.t()]) :: String.t()
  defp common_prefix(suggestions) do
    suggestions
    |> Enum.map(&String.graphemes/1)
    |> Enum.zip()
    |> Enum.reduce_while([], fn graphemes, common_prefix ->
      [ref | _] = graphemes = Tuple.to_list(graphemes)

      if Enum.all?(graphemes, &(&1 == ref)) do
        {:cont, [ref | common_prefix]}
      else
        {:halt, common_prefix}
      end
    end)
    |> Enum.reverse()
    |> IO.chardata_to_string()
  end

  @spec filter(options :: [String.t()], prefix :: String.t()) :: [String.t()]
  defp filter(options, prefix) do
    Enum.filter(options, &String.starts_with?(&1, prefix))
  end
end
