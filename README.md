# PlugLocale

Plugs for putting locale into assigns storage.

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

To integrate with other libraries, all you need is to construct a plug pipeline through `Plug.Builder`. For example:

```elixir
defmodule DemoWeb.PlugBrowserLocalization do
  use Plug.Builder

  plug PlugLocale.Browser,
    default_locale: "en",
    locales: ["en", "zh-Hans"]

  plug :set_locale

  def set_locale(conn, _opts) do
    if locale conn.assigns[:locale] do
      # use the locale
      Gettext.put_locale(locale)
    end

    conn
  end
end
```

For more information, see the [documentation](https://hexdocs.pm/plug_locale).

## License

Apache License 2.0
