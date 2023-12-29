# PlugLocale

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

Check out `PlugLocale.WebBrowser`, `PlugLocale.HTTP` in [documentation](https://hexdocs.pm/plug_locale) for more details.

## License

Apache License 2.0
