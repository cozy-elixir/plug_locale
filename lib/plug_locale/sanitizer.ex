defmodule PlugLocale.Sanitizer do
  @moduledoc """
  The default implementation is a function like `fn x -> x end`, which does
  nothing. But, in practice, you will need to set it to something meaningful.

  For example:

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

  """

  @doc false
  def sanitize(locale), do: locale
end
