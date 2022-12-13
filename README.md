# ExCLS

[![.github/workflows/ci.yml](https://github.com/visciang/excls/actions/workflows/ci.yml/badge.svg)](https://github.com/visciang/excls/actions/workflows/ci.yml) 
 [![Docs](https://img.shields.io/badge/docs-latest-green.svg)](https://visciang.github.io/excls/readme.html)

Elixir Command Line Shell - a simple framework for writing line-oriented command interpreters.

[![asciicast](https://asciinema.org/a/3k0WSKZdpwXOKMuMobfxXkJde.svg)](https://asciinema.org/a/3k0WSKZdpwXOKMuMobfxXkJde)

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
- History support via up/down key (in memory)
- Autocomplete via custom callback or `ExCLS.Autocomplete` helper
