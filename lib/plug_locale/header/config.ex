defmodule PlugLocale.Header.Config do
  @moduledoc false

  defstruct [
    :default_locale,
    :locales,
    :sanitize_locale,
    :header_name,
    :assign_key
  ]

  @doc false
  def new!(opts) when is_list(opts) do
    default_locale = Keyword.get(opts, :default_locale)
    locales = Keyword.get(opts, :locales, [])
    sanitize_locale = Keyword.get(opts, :sanitize_locale, &PlugLocale.Sanitizer.sanitize/1)
    header_name = Keyword.get(opts, :header_name, "x-client-locale")
    assign_key = Keyword.get(opts, :assign_key, :locale)

    [
      default_locale: default_locale,
      locales: locales,
      sanitize_locale: sanitize_locale,
      header_name: header_name,
      assign_key: assign_key
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
    header_name = Keyword.fetch!(opts, :header_name)
    assign_key = Keyword.fetch!(opts, :assign_key)

    %{
      default_locale: default_locale,
      locales: Enum.uniq([default_locale | locales]),
      sanitize_locale: sanitize_locale,
      header_name: header_name,
      assign_key: assign_key
    }
  end

  defp as_struct!(config) do
    default_struct = __MODULE__.__struct__()
    valid_keys = Map.keys(default_struct)
    config = Map.take(config, valid_keys)
    Map.merge(default_struct, config)
  end
end
