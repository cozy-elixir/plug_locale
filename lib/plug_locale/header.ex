defmodule PlugLocale.Header do
  @moduledoc """
  Puts locale into `assigns` storage according to given HTTP request header.

  > This is generally used by HTTP API for clients like mobile apps.

  By default, the used HTTP request header is `x-client-locale`. Although
  there's a standard HTTP header - `accept-language`, but it is better to
  use a custom header, because it is simpler and has no historical baggage
  to overcome.

  ## Usage

  First, we need to integrate this plug with other libraries, or this plug
  is useless. All you need is to construct a plug pipeline through
  `Plug.Builder`. For example:

      defmodule DemoWeb.PlugMobileClientLocalization do
        use Plug.Builder

        plug PlugLocale.Header,
          default_locale: "en",
          locales: ["en", "zh"]

        plug :put_locale

        def put_locale(conn, _opts) do
          if locale = conn.assigns[:locale] do
            # integrate with gettext
            Gettext.put_locale(locale)
          end

          conn
        end
      end

  Then, use it in router (following one is a Phoenix router, but `Plug.Router`
  is supported, too):

      defmodule DemoWeb.Router do
        use DemoWeb, :router

        pipeline :api do
          plug :accepts, ["json"]

          # ...

          plug DemoWeb.PlugMobileClientLocalization

          # ...
        end

        scope "/", DemoWeb do
          pipe_through :api

          get "/", PageController, :index
          # ...
        end
      end

  ## Options

    * `:default_locale` - the default locale.
    * `:locales` - all the supported locales.
      Default to `[]`.
    * `:cast_locale_by` - specify the function for casting extracted or
      detected locales.
      Default to `nil`.
    * `:header_name` - the header for getting locale.
      Default to `"x-client-locale"`.
    * `:assign_key` - the key for putting value into `assigns` storage.
      Default to `:locale`.

  ### about `:cast_locale_by` option

  By default, the value is `nil`, which means doing nothing. But, in practice,
  you will need to use something meaningful.

  A possible implementation:

      defmodule DemoWeb.I18n do
        def cast_locale(locale) do
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

  Then, use above implementation for plug:

      plug `#{inspect(__MODULE__)}`,
        default_locale: "en",
        locales: ["en", "zh"],
        cast_locale_by: &DemoWeb.I18n.cast_locale/1,
        # ...

  """

  @behaviour Plug

  import Plug.Conn
  alias __MODULE__.Config

  @impl true
  def init(opts), do: Config.new!(opts)

  @impl true
  def call(conn, config) do
    locale = get_locale_from_header(conn, config)
    casted_locale = cast_locale(config, locale, default: config.default_locale)

    assign(conn, config.assign_key, casted_locale)
  end

  defp get_locale_from_header(conn, config) do
    case get_req_header(conn, config.header_name) do
      [locale | _] -> locale
      _ -> nil
    end
  end

  defp cast_locale(config, locale, opts) do
    default = Keyword.get(opts, :default, nil)

    if locale do
      casted_locale =
        if config.cast_locale_by,
          do: config.cast_locale_by.(locale),
          else: locale

      if casted_locale in config.locales,
        do: casted_locale,
        else: default
    else
      default
    end
  end
end
