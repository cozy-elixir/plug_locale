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

    path = get_locale_path(conn, config, locale)

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

  defp get_locale_path(
         %Plug.Conn{private: %{plug_route: {matched_path, _}}} = conn,
         config,
         locale
       ) do
    matched_path_info = String.split(matched_path, "/", trim: true)
    is_locale_path? = inspect(config.route_identifier) in matched_path_info

    if is_locale_path? do
      path_params = conn.path_params |> Map.put(config.path_param_key, locale)

      path_info =
        Enum.map(
          matched_path_info,
          fn
            ":" <> seg -> Map.fetch!(path_params, seg)
            seg -> seg
          end
        )

      "/" <> Enum.join(path_info, "/")
    else
      path_info = [locale | conn.path_info]
      "/" <> Enum.join(path_info, "/")
    end
  end

  defp get_locale_path(%Plug.Conn{} = conn, _config, locale) do
    path_info = [locale | conn.path_info]
    "/" <> Enum.join(path_info, "/")
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
