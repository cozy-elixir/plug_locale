# Changelog

## Unreleased

New Features:

- add `PlugLocale.Browser.build_locale_url/2`

Enhancements:

- consider forwarded requests when building the paths and urls

## v0.4.0

Breaking changes:

- rename `:sanitize_locale_by` option to `:cast_locale_by`
- rename `PlugLocale.WebBrowser.build_localized_path` to `PlugLocale.WebBrowser.build_locale_path`
- rename `PlugLocale.WebBrowser` to `PlugLocale.Browser`

New Features:

- add `PlugLocale.Browser.put_locale_resp_cookie/2` / `PlugLocale.Browser.put_locale_resp_cookie/3`

## v0.3.0

Breaking changes:

- rename `:sanitize_locale` option to `:sanitize_locale_by`
