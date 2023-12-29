# PlugLocale

[![CI](https://github.com/cozy-elixir/plug_locale/actions/workflows/ci.yml/badge.svg)](https://github.com/cozy-elixir/plug_locale/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/plug_locale.svg)](https://hex.pm/packages/plug_locale)
[![built with Nix](https://img.shields.io/badge/built%20with%20Nix-5277C3?logo=nixos&logoColor=white)](https://builtwithnix.org)

Plugs for putting locale into `assigns` storage.

## Installation

Add `:plug_locale` to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:plug_locale, <requirement>}
  ]
end
```

## Usage

Different from [`set_locale`](https://hex.pm/packages/set_locale), [`ex_cldr_plugs`](https://hex.pm/packages/ex_cldr_plugs), etc, `plug_locale`:

- only does one simple thing - setting a locale-related assign (by default, it is `conn.assigns.locale`).
- does not make any assumptions about the localization strategy, so it is not tightly bound to packages like [`gettext`](https://hex.pm/packages/gettext) or [`ex_cldr`](https://hex.pm/packages/ex_cldr).

Check out `PlugLocale.WebBrowser`, `PlugLocale.Header` in [documentation](https://hexdocs.pm/plug_locale) for more details.

## Thanks

This library is built on the wisdom in following code:

- [`set_locale`](https://hex.pm/packages/set_locale)

## License

Apache License 2.0
