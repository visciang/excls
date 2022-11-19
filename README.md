# ExCLS

![CI](https://github.com/visciang/excls/workflows/CI/badge.svg) [![Docs](https://img.shields.io/badge/docs-latest-green.svg)](https://visciang.github.io/excls/readme.html)

Elixir Command Line Shell - a simple framework for writing line-oriented command interpreters.

## Usage

Escript:

```elixir

def project do
  [
    app: :mycli,
    deps: [
      {:excls, github: "visciang/excls", tag: "xxx"}
    ],
    escript: [
      emu_args: "-noinput"
    ]
  ]
end
```

Elixir script:

```elixir
#!/usr/bin/env -S elixir --erl -noinput

Mix.install([
  {:excls, github: "visciang/excls", tag: "xxx"}
])
```

## Demo app

See `demo.exs`.

## Feature

- Statefull prompt
- History support (via up/down key)
- Autocomplete (via custom callback or `ExCLS.Autocomplete` helper)
