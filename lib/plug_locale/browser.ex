defmodule PlugLocale.Browser do
  @moduledoc """
  Puts locale into `assigns` storage for Web browser environment.

  The most common way of specifying the desired locale is via the URL. In
  general, there're four methods to do that:

    1. via country-specific domain - `https://example.<locale>`, such as:
       * `https://example.is`
       * `https://example.de`
    2. via subdomain - `https://<locale>.example.com`, such as:
       * `https://en.example.com/welcome`
       * `https://zh.example.com/welcome`
    3. via path - `https://example.com/<locale>`, such as:
       * `https://example.com/en/welcome`
       * `https://example.com/zh/welcome`
    4. via query string - `https://example.com?locale=<locale>`, such as:
       * `https://example.com/welcome?locale=en`
       * `https://example.com/welcome?locale=zh`

  Method 1 and method 2 work, but they are complicated to set up and tedious
  to maintain.

  Method 4 isn't recommended. It is ugly and will confuse search engines.

  Personally, I think method 3 strikes a good balance between professionalism
  and convenience. Because of that, this plug will stick on method 3.

  ## Usage

  First, we need to integrate this plug with other libraries, or this plug
  is useless. All you need is to construct a plug pipeline through
  `Plug.Builder`. For example:

      defmodule DemoWeb.PlugBrowserLocalization do
        use Plug.Builder
      
        plug PlugLocale.Browser,
          default_locale: "en",
          locales: ["en", "zh"],
          route_identifier: :locale,
          assign_key: :locale
      
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
      
        pipeline :browser do
          plug :accepts, ["html"]

          # ...

          plug DemoWeb.PlugBrowserLocalization

          # ...
        end
      
        scope "/", DemoWeb do
          pipe_through :browser

          get "/", PageController, :index
          # ...
        end

        # Why using :locale?
        # Because it is specified by `:route_identifier` option.
        scope "/:locale", DemoWeb do
          pipe_through :browser

          get "/", PageController, :index
          # ...
        end
      end

  ## Options

    * `:default_locale` - the default locale.
    * `:locales` - all the supported locales.
      Default to `[]`.
    * `:detect_locale_from` - *the sources* and *the order of sources* for
      detecting locale.
      Available sources are `:query`, `:cookie`, `:referrer`, `:accept_language`.
      Default to `[:cookie, :referrer, :accept_language]`.
    * `:cast_locale_by` - the function for casting extracted or detected locales.
      Default to `nil`.
    * `:route_identifier` - the part for identifying locale in route.
      Default to `:locale`.
    * `:assign_key` - the key for putting value into `assigns` storage.
      Default to `:locale`.
    * `:query_key` - the key for getting locale from querystring.
      Default to `"locale"`.
    * `:cookie_key` - the key for getting locale from cookie.
      Default to `"locale"`.

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

  ## Helper functions

  `#{inspect(__MODULE__)}` also provides some helper functions, which will be useful
  when implementing UI components:

    * `build_locale_path/2`
    * `put_locale_resp_cookie/2` / `put_locale_resp_cookie/3`

  Check out their docs for more details.

  ### an example - a simple locale switcher using `build_locale_path/2`

  ```heex
  <ul>
    <li>
      <a
        href={PlugLocale.Browser.build_locale_path(@conn, "en")}
        aria-label="switch to locale - en"
      >
        English
      </a>
    </li>
    <li>
      <a
        href={PlugLocale.Browser.build_locale_path(@conn, "zh")}
        aria-label="switch to locale - zh"
      >
        中文
      </a>
    </li>
  </ul>
  ```

  ## How it works?

  This plug will try to:

    1. extract locale from URL, and check if the locale is supported:
       - If it succeeds, put locale into `assigns` storage.
       - If it fails, jump to step 2.
    2. detect locale from Web browser environment, then redirect to
       the path corresponding to detected locale.

  ### Extract locale from URL

  For example, the locale extracted from `https://example.com/en/welcome`
  is `en`.

  ### Detect locale from Web browser environment

  By default, local is detected from multiple sources:

    * query (whose key is specified by `:query_key` option)
    * cookie (whose key is specified by `:cookie_key` option)
    * HTTP request header - `Referer`
    * HTTP request header - `Accept-Language`

  If all detections fail, fallback to default locale.

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

  alias __MODULE__.Config
  alias __MODULE__.AcceptLanguage

  @private_key :plug_locale

  @impl true
  def init(opts), do: Config.new!(opts)

  @impl true
  def call(%Plug.Conn{} = conn, config) do
    locale = Map.get(conn.path_params, config.path_param_key)
    casted_locale = cast_locale(config, locale)

    if locale && casted_locale && locale == casted_locale do
      continue(conn, config, locale)
    else
      fallback(conn, config)
    end
  end

  @doc """
  Builds a localized path for current connection.

  > Note: the locale passed to this function won't be casted by the function
  > which is specified by `:cast_locale_by` option.

  ## Examples

      # the request path of conn is /posts/7
      iex> build_locale_path(conn, "en")
      "/en/posts/7"

      # the request path of conn is /en/posts/7
      iex> build_locale_path(conn, "zh")
      "/zh/posts/7"

  """
  @spec build_locale_path(Plug.Conn.t(), String.t()) :: String.t()
  def build_locale_path(%Plug.Conn{} = conn, locale) do
    %{config: config} = Map.fetch!(conn.private, @private_key)
    __build_locale_path__(conn, config, locale)
  end

  @doc """
  Builds a localized url for current connection.

  > Note: the locale passed to this function won't be casted by the function
  > which is specified by `:cast_locale_by` option.

  ## Examples

      # the request path of conn is /posts/7
      iex> build_locale_path(conn, "en")
      "http://www.example.com/en/posts/7"

      # the request path of conn is /en/posts/7
      iex> build_locale_path(conn, "zh")
      "http://www.example.com/zh/posts/7"

  """
  @spec build_locale_url(Plug.Conn.t(), String.t()) :: String.t()
  def build_locale_url(%Plug.Conn{} = conn, locale) do
    %{config: config} = Map.fetch!(conn.private, @private_key)

    %{scheme: scheme, host: host, port: port} = __extra_base_url_parts__(conn)
    %{query_string: query} = conn
    path = __build_locale_path__(conn, config, locale)

    build_url(scheme, host, port, path, query)
  end

  @doc """
  Puts a response cookie for locale in the connection.

  This is a simple wrapper around `Plug.Conn.put_resp_cookie/4`. See its docs
  for more details.

  ## Examples

      iex> put_locale_resp_cookie(conn, "en")
      iex> put_locale_resp_cookie(conn, "zh", max_age: 365 * 24 * 60 * 60)

  ## Use cases

  Use this function to persistent current locale into cookie, then subsequent
  requests can directly read the locale from the cookie.

      defmodule DemoWeb.PlugBrowserLocalization do
        use Plug.Builder
      
        plug PlugLocale.Browser,
          default_locale: "en",
          locales: ["en", "zh"],
          route_identifier: :locale,
          assign_key: :locale
      
        plug :put_locale
      
        def put_locale(conn, _opts) do
          if locale = conn.assigns[:locale] do
            # integrate with gettext
            Gettext.put_locale(locale)

            # persistent current locale into cookie
            PlugLocale.Browser.put_locale_resp_cookie(
              conn,
              locale,
              max_age: 365 * 24 * 60 * 60
            )
          else
            conn
          end
        end
      end

  """
  @spec put_locale_resp_cookie(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def put_locale_resp_cookie(%Plug.Conn{} = conn, locale, opts \\ []) do
    %{config: %{cookie_key: key}} = Map.fetch!(conn.private, @private_key)
    put_resp_cookie(conn, key, locale, opts)
  end

  defp continue(conn, config, locale) do
    conn
    |> put_private(@private_key, %{config: config})
    |> assign(config.assign_key, locale)
  end

  defp fallback(conn, config) do
    locale =
      Enum.reduce_while(config.detect_locale_from, nil, fn source, _acc ->
        if locale = detect_locale(source, conn, config),
          do: {:halt, locale},
          else: {:cont, nil}
      end)

    locale = cast_locale(config, locale, default: config.default_locale)

    path = __build_locale_path__(conn, config, locale)

    conn
    |> redirect_to(path)
    |> halt()
  end

  # support for Phoenix
  defp __extra_base_url_parts__(%Plug.Conn{private: %{phoenix_endpoint: endpoint}}) do
    endpoint.struct_url()
    |> Map.take([:scheme, :host, :port])
  end

  # support for Plug
  defp __extra_base_url_parts__(%Plug.Conn{} = conn) do
    Map.take(conn, [:scheme, :host, :port])
  end

  # support for Phoenix
  defp __build_locale_path__(
         %Plug.Conn{private: %{phoenix_router: router}} = conn,
         config,
         locale
       ) do
    %{script_name: script_name} = conn
    route_info = phoenix_route_info(router, conn)
    path_info = convert_route_info_to_path_info(route_info, conn, config, locale)
    build_path(script_name ++ path_info)
  end

  # support for Plug
  defp __build_locale_path__(
         %Plug.Conn{private: %{plug_route: {_route, _callback}}} = conn,
         config,
         locale
       ) do
    %{script_name: script_name} = conn
    route_info = plug_route_info(conn)
    path_info = convert_route_info_to_path_info(route_info, conn, config, locale)
    build_path(script_name ++ path_info)
  end

  defp __build_locale_path__(%Plug.Conn{} = conn, _config, locale) do
    %{path_info: path_info, script_name: script_name} = conn
    build_path(script_name ++ [locale | path_info])
  end

  defp convert_route_info_to_path_info(
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

      Enum.map(route_path_info, fn
        ":" <> seg -> Map.fetch!(path_params, seg)
        seg -> seg
      end)
    else
      [locale | conn.path_info]
    end
  end

  defp build_url(scheme, host, port, path, query) do
    scheme = to_string(scheme)
    query = if query == "", do: nil, else: query

    to_string(%URI{
      scheme: scheme,
      host: host,
      port: port,
      path: path,
      query: query
    })
  end

  defp build_path(path_info) when is_list(path_info) do
    "/" <> Enum.join(path_info, "/")
  end

  defp build_path_info(nil), do: []

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

  defp redirect_to(conn, path) do
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

  defp detect_locale(:query, %Plug.Conn{query_params: %Plug.Conn.Unfetched{}}, _config) do
    Logger.warning(
      ":query_params of conn is still unfetched when calling #{inspect(__MODULE__)}, " <>
        "skip getting locale from it"
    )

    nil
  end

  defp detect_locale(:query, conn, config) do
    conn.query_params[config.query_key]
  end

  defp detect_locale(:cookie, %Plug.Conn{cookies: %Plug.Conn.Unfetched{}}, _config) do
    Logger.warning(
      ":cookies of conn is still unfetched when calling #{inspect(__MODULE__)}, " <>
        "skip getting locale from it"
    )

    nil
  end

  defp detect_locale(:cookie, conn, config) do
    conn.cookies[config.cookie_key]
  end

  defp detect_locale(:referrer, conn, _config) do
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

  defp detect_locale(:accept_language, conn, config) do
    case get_req_header(conn, "accept-language") do
      [accept_language | _] ->
        accept_language
        |> AcceptLanguage.extract_locales()
        |> Enum.find(nil, fn locale ->
          cast_locale(config, locale)
        end)

      _ ->
        nil
    end
  end

  defp detect_locale(source, _conn, _config) do
    raise RuntimeError, "unknown source for detecting locale - #{inspect(source)}"
  end

  defp cast_locale(config, locale, opts \\ []) do
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
