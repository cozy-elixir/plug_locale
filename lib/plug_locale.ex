defmodule PlugLocale do
  @moduledoc """

  This plug works by:

    1. reading locale from path_params:
       * if the locale is not set, then jump to step 2.
       * if the locale is set but invalid, then jump to step 2.
       * if the locale is set and valid, then use it directly
    2. detecting locale according to:
       a. cookie
       b. HTTP header - referrer
       c. HTTP header - accept-language
       d. default locale

  """

  require Logger

  @behaviour Plug
  import Plug.Conn

  alias __MODULE__.Config
  alias __MODULE__.AcceptLanguage

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

  # Phoenix provides `Phoenix.Router.router_info/4`, but I don't want this
  # library to depend on Phoenix directly. So, I implement a simple version
  # of it according to
  # https://github.com/phoenixframework/phoenix/blob/a66e7c33019a3d564c4f7f2e48b77efb63c54ad7/lib/phoenix/router.ex#L1220
  defp phoenix_route_info(router, conn) do
    %{method: method, host: host, path_info: path_info} = conn

    with {metadata, _prepare, _pipeline, {_plug, _opts}} <-
           router.__match_route__(path_info, method, host) do
      %{
        path_info: String.split(metadata.route, "/", trim: true),
        path_params: metadata.path_params
      }
    end
  end

  defp plug_route_info(conn) do
    %{private: %{plug_route: {route, _callback}}} = conn

    %{
      path_info: String.split(route, "/", trim: true),
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
        path_info = String.split(uri.path, "/", trim: true)

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
