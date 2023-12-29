defmodule PlugLocale.WebBrowser do
  @moduledoc """
  Puts locale into `assigns` storage for Web browser environment.

  The most common way of specifying the desired locale is via the URL. In
  general, there're three methods to do that:

    1. via domain name - `https://<locale>.example.com`, such as:
       * `https://en.example.com/welcome`
       * `https://zh.example.com/welcome`
    2. via path - `https://example.com/<locale>`, such as:
       * `https://example.com/en/welcome`
       * `https://example.com/zh/welcome`
    3. via querystring - `https://example.com?locale=<locale>`, such as:
       * `https://example.com/welcome?locale=en`
       * `https://example.com/welcome?locale=zh`

  Personally, I think method 2 is better，compared to the other two methods:

    * Method 1 is tedious for deployment.
    * URL generated by method 3 looks very ugly and unprofessional.

  Because of that, this plug will stick on method 2.

  ## Usage

  First, we need to integrate this plug with other libraries, or this plug
  is useless. All you need is to construct a plug pipeline through
  `Plug.Builder`. For example:

      defmodule DemoWeb.PlugWebBrowserLocalization do
        use Plug.Builder
      
        plug PlugLocale.WebBrowser,
          default_locale: "en",
          locales: ["en", "zh"]
      
        plug :set_locale
      
        def set_locale(conn, _opts) do
          if locale conn.assigns[:locale] do
            # integrate with gettext
            Gettext.put_locale(locale)
          end
      
          conn
        end
      end

  Then, use it in router:

      defmodule DemoWeb.Router do
        use DemoWeb, :router
      
        pipeline :browser do
          plug :accepts, ["html"]

          # ...

          plug PlugLocale.WebBrowser
            default_locale: "en",
            locales: ["en", "zh"],
            route_identifier: :locale,
            assign_key: :locale,
            cookie_key: "locale"

          # ...
        end
      
        scope "/", DemoWeb do
          pipe_through :browser

          get "/", PageController, :index
          # ...
        end
      
        scope "/:locale", DemoWeb do
          pipe_through :browser

          get "/", PageController, :index
          # ...
        end
      end

  ## Options

    * `:default_locale` - the default locale.
    * `:locales` - all the supported locales. Default to `[]`.
    * `:sanitize_locale` - a function for sanitizing extracted or detected
      locales. Default to `&PlugLocale.Sanitizer.sanitize/1` which does
      nothing.
    * `:route_identifier` - the part for identifying locale in route.
      Default to `:locale`.
    * `:assign_key` - the key for putting value into `assigns` storage.
      Default to the value of `:route_identifier` option.
    * `:cookie_key` - the key for reading locale from cookie.
      Default to `"preferred_locale"`.

  ## How it works?

  This plug will try to:

    1. extract locale from URL, and check if the locale is supported:
       - If it succeeds, put locale into `assigns` storage。
       - If it fails, jump to step 2.
    2. detect locale from Web browser environment, then redirect to
       the path corresponding to detected locale.

  ### Extract locale from URL

  For example, the locale extracted from `https://example.com/en/welcome`
  is `en`.

  ### Detect locale from Web browser environment

  Local is detected from multiple places:

    * cookie (whose key is specified by `:cookie_key` option)
    * HTTP request header - `referer`
    * HTTP request header - `accept-language`
    * default locale (which is specified by `:default_locale` option)

  ## Examples

  When:

    * `:default_locale` option is set to `"en"`
    * `:locales` option is set to `["en", "zh"]`

  For users in an English-speaking environment:

    * `https://example.com/en` will be responded directly.
    * `https://example.com/` will be redirected to `https://example.com/en`.
    * `https://example.com/path` will be redirected to `https://example.com/en/path`.
    * `https://example.com/unknown` will be redirected to `https://example.com/en`.
    * ...

  For users in an Chinese-speaking environment:

    * `https://example.com/zh` will be responded directly.
    * `https://example.com/` will be redirected to `https://example.com/zh`.
    * `https://example.com/path` will be redirected to `https://example.com/zh/path`.
    * `https://example.com/unknown` will be redirected to `https://example.com/zh`.
    * ...

  """

  require Logger

  @behaviour Plug
  import Plug.Conn

  alias PlugLocale.Config
  alias PlugLocale.WebBrowser.AcceptLanguage

  @impl true
  def init(opts), do: Config.new!(opts)

  @impl true
  def call(%Plug.Conn{} = conn, config) do
    locale = Map.get(conn.path_params, config.path_param_key)

    locale = sanitize_locale(config, locale)

    if locale do
      continue(conn, config, locale)
    else
      fallback(conn, config)
    end
  end

  defp continue(conn, config, locale) do
    assign(conn, config.assign_key, locale)
  end

  defp fallback(conn, config) do
    locale =
      get_locale(:cookie, conn, config) ||
        get_locale(:referrer, conn, config) ||
        get_locale(:header, conn, config)

    locale = sanitize_locale(config, locale, default: config.default_locale)

    path = build_locale_path(conn, config, locale)

    conn
    |> redirect_to(path)
    |> halt()
  end

  defp sanitize_locale(config, locale, opts \\ []) do
    default = Keyword.get(opts, :default, nil)

    if locale do
      locale = config.sanitize_locale.(locale)
      if locale in config.locales, do: locale, else: default
    else
      default
    end
  end

  # support for Phoenix
  defp build_locale_path(
         %Plug.Conn{private: %{phoenix_router: router}} = conn,
         config,
         locale
       ) do
    route_info = phoenix_route_info(router, conn)
    convert_route_info_to_locale_path(route_info, conn, config, locale)
  end

  # support for Plug
  defp build_locale_path(
         %Plug.Conn{private: %{plug_route: {_route, _callback}}} = conn,
         config,
         locale
       ) do
    route_info = plug_route_info(conn)
    convert_route_info_to_locale_path(route_info, conn, config, locale)
  end

  defp build_locale_path(%Plug.Conn{} = conn, _config, locale) do
    build_path([locale | conn.path_info])
  end

  defp convert_route_info_to_locale_path(
         %{
           path_info: route_path_info,
           path_params: route_path_params
         },
         conn,
         config,
         locale
       ) do
    is_locale_path? = inspect(config.route_identifier) in route_path_info

    if is_locale_path? do
      path_params = Map.put(route_path_params, config.path_param_key, locale)

      path_info =
        Enum.map(
          route_path_info,
          fn
            ":" <> seg -> Map.fetch!(path_params, seg)
            seg -> seg
          end
        )

      build_path(path_info)
    else
      build_path([locale | conn.path_info])
    end
  end

  defp build_path(path_info) when is_list(path_info) do
    "/" <> Enum.join(path_info, "/")
  end

  defp build_path_info(path) when is_binary(path) do
    String.split(path, "/", trim: true)
  end

  # Phoenix provides `Phoenix.Router.router_info/4`, but I don't want this
  # library to depend on Phoenix directly. So, I implement a simple version
  # of it according to
  # https://github.com/phoenixframework/phoenix/blob/a66e7c33019a3d564c4f7f2e48b77efb63c54ad7/lib/phoenix/router.ex#L1220
  defp phoenix_route_info(router, conn) do
    %{method: method, host: host, path_info: path_info} = conn

    with {metadata, _prepare, _pipeline, {_plug, _opts}} <-
           router.__match_route__(path_info, method, host) do
      %{
        path_info: build_path_info(metadata.route),
        path_params: metadata.path_params
      }
    end
  end

  defp plug_route_info(conn) do
    %{private: %{plug_route: {route, _callback}}} = conn

    %{
      path_info: build_path_info(route),
      path_params: conn.path_params
    }
  end

  def redirect_to(conn, path) do
    url = path
    html = Plug.HTML.html_escape(url)
    body = "<html><body>You are being <a href=\"#{html}\">redirected</a>.</body></html>"

    conn
    |> put_resp_header("location", url)
    |> send_resp(302, "text/html", body)
  end

  defp send_resp(conn, default_status, default_content_type, body) do
    conn
    |> ensure_resp_content_type(default_content_type)
    |> send_resp(conn.status || default_status, body)
  end

  defp ensure_resp_content_type(%Plug.Conn{resp_headers: resp_headers} = conn, content_type) do
    if List.keyfind(resp_headers, "content-type", 0) do
      conn
    else
      content_type = content_type <> "; charset=utf-8"
      %Plug.Conn{conn | resp_headers: [{"content-type", content_type} | resp_headers]}
    end
  end

  defp get_locale(
         :cookie,
         %Plug.Conn{
           cookies: %Plug.Conn.Unfetched{}
         } = _conn,
         _config
       ) do
    # TODO: add warning for unfetched cookies
    nil
  end

  defp get_locale(
         :cookie,
         %Plug.Conn{} = conn,
         config
       ) do
    conn.cookies[config.cookie_key]
  end

  defp get_locale(:referrer, conn, _config) do
    case get_req_header(conn, "referer") do
      [referrer | _] ->
        uri = URI.parse(referrer)
        path_info = build_path_info(uri.path)

        case path_info do
          [locale | _] -> locale
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp get_locale(:header, conn, config) do
    case get_req_header(conn, "accept-language") do
      [accept_language | _] ->
        accept_language
        |> AcceptLanguage.extract_locales()
        |> Enum.find(nil, fn locale ->
          sanitize_locale(config, locale)
        end)

      _ ->
        nil
    end
  end
end
