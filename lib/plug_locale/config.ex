defmodule PlugLocale.Config do
  @moduledoc false

  defstruct [
    :default_locale,
    :locales,
    :sanitize_locale,
    :route_identifier,
    :path_param_key,
    :assign_key,
    :cookie_key
  ]

  @doc false
  def new!(opts) when is_list(opts) do
    default_locale = Keyword.get(opts, :default_locale)
    locales = Keyword.get(opts, :locales, [])
    sanitize_locale = Keyword.get(opts, :sanitize_locale, &PlugLocale.Sanitizer.sanitize/1)
    route_identifier = Keyword.get(opts, :route_identifier, :locale)
    assign_key = Keyword.get(opts, :assign_key, route_identifier)
    cookie_key = Keyword.get(opts, :cookie_key, "preferred_locale")

    [
      default_locale: default_locale,
      locales: locales,
      sanitize_locale: sanitize_locale,
      route_identifier: route_identifier,
      assign_key: assign_key,
      cookie_key: cookie_key
    ]
    |> validate!()
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
    sanitize_locale = Keyword.fetch!(opts, :sanitize_locale)
    route_identifier = Keyword.fetch!(opts, :route_identifier)
    assign_key = Keyword.fetch!(opts, :assign_key)
    cookie_key = Keyword.fetch!(opts, :cookie_key)

    %{
      default_locale: default_locale,
      locales: Enum.uniq([default_locale | locales]),
      sanitize_locale: sanitize_locale,
      route_identifier: route_identifier,
      path_param_key: Atom.to_string(route_identifier),
      assign_key: assign_key,
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
