defmodule ExCLS do
  @moduledoc """
  Elixir Command Line Shell.

  A simple framework for writing line-oriented command interpreters.
  """

  @typedoc """
  Behaviour module.
  """
  @type t :: module()

  @typedoc """
  Behaviour state.
  """
  @type state :: term()

  @doc """
  Initialization function.
  """
  @callback init() :: state()

  @doc """
  Intro banner.

  A string to issue as an intro or banner.
  """
  @callback intro() :: IO.chardata()

  @doc """
  Prompt function.

  The prompt issued to solicit input.
  """
  @callback prompt(state()) :: IO.chardata()

  @doc """
  Command function.

  Interpret the argument as though it had been typed in response to the prompt.
  """
  @callback command(line :: String.t(), state()) ::
              {:ok, IO.chardata(), next :: state()}
              | {:stop, IO.chardata(), exit_code :: non_neg_integer()}

  @doc """
  Autocomplete function.

  Suggest autocomplete options when a tab key is pressed.
  """
  @callback autocomplete(line :: String.t(), cursor_at :: non_neg_integer(), state()) ::
              {
                :suggest,
                completed_line :: IO.chardata(),
                cursor_idx :: non_neg_integer(),
                options :: [IO.chardata()],
                next :: state()
              }
              | {
                  :done,
                  completed_line :: nil | IO.chardata(),
                  next :: state()
                }

  @optional_callbacks intro: 0, autocomplete: 3

  defdelegate run(behaviour, opts), to: ExCLS.Shell
end
