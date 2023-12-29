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
    * `:locales` - all the supported locales. Default to `[]`.
    * `:sanitize_locale` - a function for sanitizing extracted or detected
      locales. Default to `&PlugLocale.Sanitizer.sanitize/1` which does
      nothing. See `PlugLocale.Sanitizer` for more details.
    * `:header_name` - the header for getting locale.
      Default to `"x-client-locale"`.
    * `:assign_key` - the key for putting value into `assigns` storage.
      Default to `:locale`.

  """

  @behaviour Plug

  import Plug.Conn
  alias __MODULE__.Config

  @impl true
  def init(opts), do: Config.new!(opts)

  @impl true
  def call(conn, config) do
    locale = get_locale_from_header(conn, config)

    locale =
      if locale do
        locale = config.sanitize_locale.(locale)
        if locale in config.locales, do: locale, else: config.default_locale
      else
        config.default_locale
      end

    assign(conn, config.assign_key, locale)
  end

  defp get_locale_from_header(conn, config) do
    case get_req_header(conn, config.header_name) do
      [locale | _] -> locale
      _ -> nil
    end
  end
end
