defmodule PlugLocale.HeaderTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule DemoRouter do
    use Plug.Router

    plug :match

    plug PlugLocale.Header,
      default_locale: "en",
      locales: ["en", "zh-Hans"]

    plug :dispatch

    get "/posts/:id" do
      %{"id" => id} = conn.params
      %{locale: locale} = conn.assigns
      send_resp(conn, 200, "post: #{locale} - #{id}")
    end

    match _ do
      send_resp(conn, 404, "oops")
    end
  end

  @opts DemoRouter.init([])

  test "request without header" do
    conn = conn(:get, "/posts/7")
    conn = DemoRouter.call(conn, @opts)

    assert conn.status == 200
    assert conn.assigns.locale == "en"
    assert conn.resp_body == "post: en - 7"
  end

  test "request with known header" do
    conn =
      conn(:get, "/posts/7")
      |> put_req_header("x-client-locale", "zh-Hans")

    conn = DemoRouter.call(conn, @opts)

    assert conn.status == 200
    assert conn.assigns.locale == "zh-Hans"
    assert conn.resp_body == "post: zh-Hans - 7"
  end

  test "request with unknown header" do
    conn =
      conn(:get, "/posts/7")
      |> put_req_header("x-client-locale", "unknown")

    conn = DemoRouter.call(conn, @opts)

    assert conn.status == 200
    assert conn.assigns.locale == "en"
    assert conn.resp_body == "post: en - 7"
  end
end
