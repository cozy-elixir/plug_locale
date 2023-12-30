defmodule PlugLocale.WebBrowser.Config do
  @moduledoc false

  defstruct [
    :default_locale,
    :locales,
    :detect_locale_from,
    :cast_locale_by,
    :route_identifier,
    :path_param_key,
    :assign_key,
    :query_key,
    :cookie_key
  ]

  @doc false
  def new!(opts) when is_list(opts) do
    default_locale = Keyword.get(opts, :default_locale)
    locales = Keyword.get(opts, :locales, [])

    detect_locale_from =
      Keyword.get(opts, :detect_locale_from, [:cookie, :referrer, :accept_language])

    cast_locale_by = Keyword.get(opts, :cast_locale_by, nil)
    route_identifier = Keyword.get(opts, :route_identifier, :locale)
    assign_key = Keyword.get(opts, :assign_key, route_identifier)
    query_key = Keyword.get(opts, :query_key, to_string(route_identifier))
    cookie_key = Keyword.get(opts, :cookie_key, "preferred_locale")

    [
      default_locale: default_locale,
      locales: locales,
      detect_locale_from: detect_locale_from,
      cast_locale_by: cast_locale_by,
      route_identifier: route_identifier,
      assign_key: assign_key,
      query_key: query_key,
      cookie_key: cookie_key
    ]
    |> as_map!()
    |> as_struct!()
  end

  defp validate!(opts) do
    keys = Keyword.keys(opts)
    unset_keys = Enum.filter(keys, fn key -> Keyword.get(opts, key) == nil end)

    if unset_keys != [] do
      raise RuntimeError, "following keys #{inspect(unset_keys)} should be set"
    end

    opts
  end

  defp as_map!(opts) do
    default_locale = Keyword.fetch!(opts, :default_locale)
    locales = Keyword.fetch!(opts, :locales)
    detect_locale_from = Keyword.fetch!(opts, :detect_locale_from)
    cast_locale_by = Keyword.fetch!(opts, :cast_locale_by)
    route_identifier = Keyword.fetch!(opts, :route_identifier)
    assign_key = Keyword.fetch!(opts, :assign_key)
    query_key = Keyword.fetch!(opts, :query_key)
    cookie_key = Keyword.fetch!(opts, :cookie_key)

    %{
      default_locale: default_locale,
      locales: Enum.uniq([default_locale | locales]),
      detect_locale_from: detect_locale_from,
      cast_locale_by: cast_locale_by,
      route_identifier: route_identifier,
      path_param_key: to_string(route_identifier),
      assign_key: assign_key,
      query_key: query_key,
      cookie_key: cookie_key
    }
  end

  defp as_struct!(config) do
    default_struct = __MODULE__.__struct__()
    valid_keys = Map.keys(default_struct)
    config = Map.take(config, valid_keys)
    Map.merge(default_struct, config)
  end
end
