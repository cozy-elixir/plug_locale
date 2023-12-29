defmodule PlugLocale.WebBrowserTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule DemoRouter do
    use Plug.Router

    plug :match

    plug PlugLocale.WebBrowser,
      default_locale: "en",
      locales: ["en", "zh-Hans"]

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

  @opts DemoRouter.init([])

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
    test "is redirected to a detected path - default locale" do
      conn = conn(:get, "/unknown-locale/posts/7")
      conn = DemoRouter.call(conn, @opts)

      assert conn.status == 302
      assert conn.assigns[:locale] == nil
      assert conn.resp_body =~ "\"/en/posts/7\""
    end

    test "is redirected to a detected path from referrer header" do
      conn =
        conn(:get, "/unknown-locale/posts/7")
        |> put_req_header("referer", "/zh-Hans/origin")

      conn = DemoRouter.call(conn, @opts)

      assert conn.status == 302
      assert conn.assigns[:locale] == nil
      assert conn.resp_body =~ "\"/zh-Hans/posts/7\""
    end

    test "is redirected to a detected path from accept-language header" do
      conn =
        conn(:get, "/unknown-locale/posts/7")
        |> put_req_header("accept-language", "de, en-gb;q=0.8, zh-Hans;q=0.9, en;q=0.7")

      conn = DemoRouter.call(conn, @opts)

      assert conn.status == 302
      assert conn.assigns[:locale] == nil
      assert conn.resp_body =~ "\"/zh-Hans/posts/7\""
    end
  end

  # TODO: add tests for Phoenix router
end
