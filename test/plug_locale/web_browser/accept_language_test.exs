defmodule PlugLocale.WebBrowser.AcceptLanguageTest do
  use ExUnit.Case, async: true
  alias PlugLocale.WebBrowser.AcceptLanguage

  describe "extract_locales/1" do
    test "works for normal languages" do
      assert AcceptLanguage.extract_locales("en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7") ==
               ["en-US", "en", "zh-CN", "zh"]
    end

    test "works for languages with extra spaces" do
      assert AcceptLanguage.extract_locales("en-US, en;q=0.9, zh-CN;q=0.8, zh;q=0.7") ==
               ["en-US", "en", "zh-CN", "zh"]
    end

    test "works for languages in arbitrary order" do
      assert AcceptLanguage.extract_locales("en-US,zh-CN;q=0.8,zh;q=0.7,en;q=0.9") ==
               ["en-US", "en", "zh-CN", "zh"]
    end
  end
end
