defmodule PlugLocale.BrowserTest do
  use ExUnit.Case, async: true
  use Plug.Test
  import ExUnit.CaptureLog

  defmodule DemoRouter do
    use Plug.Router

    plug :match

    plug Plug.Parsers,
      parsers: [:urlencoded]

    plug PlugLocale.Browser,
      default_locale: "en",
      locales: ["en", "zh-Hans"],
      detect_locale_from: [:query, :cookie, :referrer, :accept_language]

    plug :dispatch

    get "/posts/:id" do
      %{"id" => id} = conn.params
      send_resp(conn, 200, "post: #{id}")
    end

    get "/:locale/posts/:id" do
      %{"id" => id} = conn.params
      %{locale: locale} = conn.assigns
      send_resp(conn, 200, "post: #{locale} - #{id}")
    end

    match _ do
      send_resp(conn, 404, "oops")
    end
  end

  defmodule DemoRouterWithoutParsers do
    use Plug.Router

    plug :match

    plug PlugLocale.Browser,
      default_locale: "en",
      locales: ["en", "zh-Hans"],
      detect_locale_from: [:query, :cookie, :referrer, :accept_language]

    plug :dispatch

    get "/posts/:id" do
      %{"id" => id} = conn.params
      send_resp(conn, 200, "post: #{id}")
    end

    get "/:locale/posts/:id" do
      %{"id" => id} = conn.params
      %{locale: locale} = conn.assigns
      send_resp(conn, 200, "post: #{locale} - #{id}")
    end

    match _ do
      send_resp(conn, 404, "oops")
    end
  end

  defmodule DemoRouterWithPuttingCookie do
    use Plug.Router

    plug :match

    plug PlugLocale.Browser,
      default_locale: "en",
      locales: ["en", "zh-Hans"],
      detect_locale_from: [:query, :cookie, :referrer, :accept_language]

    plug :put_cookie

    plug :dispatch

    def put_cookie(conn, _opts) do
      if locale = conn.assigns[:locale] do
        PlugLocale.Browser.put_locale_resp_cookie(conn, locale, max_age: 3600)
      else
        conn
      end
    end

    get "/posts/:id" do
      %{"id" => id} = conn.params
      send_resp(conn, 200, "post: #{id}")
    end

    get "/:locale/posts/:id" do
      %{"id" => id} = conn.params
      %{locale: locale} = conn.assigns
      send_resp(conn, 200, "post: #{locale} - #{id}")
    end

    match _ do
      send_resp(conn, 404, "oops")
    end
  end

  @opts []

  describe "path without locale" do
    test "is redirected to a detected path - default locale" do
      conn = conn(:get, "/posts/7")
      conn = DemoRouter.call(conn, @opts)

      assert conn.status == 302
      assert conn.assigns[:locale] == nil
      assert conn.resp_body =~ "\"/en/posts/7\""
    end

    test "is redirected to a detected path from referrer header" do
      conn =
        conn(:get, "/posts/7")
        |> put_req_header("referer", "/zh-Hans/origin")

      conn = DemoRouter.call(conn, @opts)

      assert conn.status == 302
      assert conn.assigns[:locale] == nil
      assert conn.resp_body =~ "\"/zh-Hans/posts/7\""
    end

    test "is redirected to a detected path from accept-language header" do
      conn =
        conn(:get, "/posts/7")
        |> put_req_header("accept-language", "de, en-gb;q=0.8, zh-Hans;q=0.9, en;q=0.7")

      conn = DemoRouter.call(conn, @opts)

      assert conn.status == 302
      assert conn.assigns[:locale] == nil
      assert conn.resp_body =~ "\"/zh-Hans/posts/7\""
    end
  end

  describe "path with known locale" do
    test "is responded directly - default locale" do
      conn = conn(:get, "/en/posts/7")
      conn = DemoRouter.call(conn, @opts)

      assert conn.status == 200
      assert conn.assigns.locale == "en"
      assert conn.resp_body == "post: en - 7"
    end

    test "is responded directly - other known locales" do
      conn = conn(:get, "/zh-Hans/posts/7")
      conn = DemoRouter.call(conn, @opts)

      assert conn.status == 200
      assert conn.assigns.locale == "zh-Hans"
      assert conn.resp_body == "post: zh-Hans - 7"
    end
  end

  describe "path with unknown locale" do
    test "is redirected to a path detected from query" do
      conn = conn(:get, "/unknown-locale/posts/7?locale=zh-Hans")
      conn = DemoRouter.call(conn, @opts)

      assert conn.status == 302
      assert conn.assigns[:locale] == nil
      assert conn.resp_body =~ "\"/zh-Hans/posts/7\""
    end

    test "is redirected to a path detected from cookie" do
      conn =
        conn(:get, "/unknown-locale/posts/7")
        |> put_resp_cookie("locale", "zh-Hans")
        |> fetch_cookies()

      conn = DemoRouter.call(conn, @opts)

      assert conn.status == 302
      assert conn.assigns[:locale] == nil
      assert conn.resp_body =~ "\"/zh-Hans/posts/7\""
    end

    test "is redirected to a path detected from referrer header - detect locale from standard path" do
      conn =
        conn(:get, "/unknown-locale/posts/7")
        |> put_req_header("referer", "http://example.com/zh-Hans/origin")

      conn = DemoRouter.call(conn, @opts)

      assert conn.status == 302
      assert conn.assigns[:locale] == nil
      assert conn.resp_body =~ "\"/zh-Hans/posts/7\""
    end

    test "is redirected to a path detected from referrer header - fallback to default locale for non-standard path" do
      conn =
        conn(:get, "/unknown-locale/posts/7")
        |> put_req_header("referer", "http://example.com")

      conn = DemoRouter.call(conn, @opts)

      assert conn.status == 302
      assert conn.assigns[:locale] == nil
      assert conn.resp_body =~ "\"/en/posts/7\""
    end

    test "is redirected to a path detected from accept-language header" do
      conn =
        conn(:get, "/unknown-locale/posts/7")
        |> put_req_header("accept-language", "de, en-gb;q=0.8, zh-Hans;q=0.9, en;q=0.7")

      conn = DemoRouter.call(conn, @opts)

      assert conn.status == 302
      assert conn.assigns[:locale] == nil
      assert conn.resp_body =~ "\"/zh-Hans/posts/7\""
    end

    test "is redirected to a detected path - default locale" do
      conn = conn(:get, "/unknown-locale/posts/7")
      conn = DemoRouter.call(conn, @opts)

      assert conn.status == 302
      assert conn.assigns[:locale] == nil
      assert conn.resp_body =~ "\"/en/posts/7\""
    end
  end

  test "show a warning when the required data is unfetched" do
    conn = conn(:get, "/unknown-locale/posts/7")

    opts = DemoRouterWithoutParsers.init([])
    log = capture_log(fn -> DemoRouterWithoutParsers.call(conn, opts) end)

    assert log =~ ":query_params of conn is still unfetched"
    assert log =~ ":cookies of conn is still unfetched"
  end

  test "build_locale_path/2" do
    conn = conn(:get, "/en/posts/7")
    conn = DemoRouter.call(conn, @opts)
    assert "/zh-Hans/posts/7" == PlugLocale.Browser.build_locale_path(conn, "zh-Hans")
  end

  test "build_locale_url/2" do
    conn = conn(:get, "/en/posts/7")
    conn = DemoRouter.call(conn, @opts)

    assert "http://www.example.com/zh-Hans/posts/7" ==
             PlugLocale.Browser.build_locale_url(conn, "zh-Hans")
  end

  test "put_locale_resp_cookie/2" do
    conn = conn(:get, "/en/posts/7")
    conn = DemoRouterWithPuttingCookie.call(conn, @opts)
    assert %Plug.Conn{cookies: %{"locale" => "en"}} = fetch_cookies(conn)
  end

  # credo:disable-for-next-line
  # TODO: add tests for Phoenix router
end
