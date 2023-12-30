defmodule PlugLocale.Sanitizer do
  @moduledoc """
  The default implementation is a function like `fn x -> x end`, which does
  nothing. But, in practice, you will need to use something meaningful.

  A possible implementation:

      defmodule DemoWeb.LocaleSanitizer do
        def sanitize(locale) do
          case locale do
            # explicit matching on supported locales
            locale when locale in ["en", "zh"] ->
              locale

            # fuzzy matching on en locale
            "en-" <> _ ->
              "en"

            # fuzzy matching on zh locale
            "zh-" <> _ ->
              "zh"

            # fallback for unsupported locales
            _ ->
              "en"
          end
        end
      end

  Then, use above implementation in plugs by using `:sanitize_locale_by` option:

      # use it for PlugLocale.WebBrowser
      plug PlugLocale.WebBrowser,
        default_locale: "en",
        locales: ["en", "zh"],
        sanitize_locale_by: &DemoWeb.LocaleSanitizer.sanitize/1,
        # ...

      # use it for PlugLocale.Header
      plug PlugLocale.Header,
        default_locale: "en",
        locales: ["en", "zh"],
        sanitize_locale_by: &DemoWeb.LocaleSanitizer.sanitize/1,
        # ...

  """

  @doc false
  def sanitize(locale), do: locale
end
