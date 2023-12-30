defmodule PlugLocale.WebBrowser.Config do
  @moduledoc false

  @opts_schema [
    default_locale: [
      type: :string,
      required: true
    ],
    locales: [
      type: {:list, :string},
      default: []
    ],
    detect_locale_from: [
      type: {:list, :atom},
      default: [:cookie, :referrer, :accept_language]
    ],
    cast_locale_by: [
      type: {:or, [nil, {:fun, 1}]},
      default: nil
    ],
    route_identifier: [
      type: :atom,
      default: :locale
    ],
    assign_key: [
      type: :atom,
      default: :locale
    ],
    query_key: [
      type: :string,
      default: "locale"
    ],
    cookie_key: [
      type: :string,
      default: "locale"
    ]
  ]

  @direct_fields Keyword.keys(@opts_schema)
  @derived_fields [:path_param_key]

  defstruct @direct_fields ++ @derived_fields

  @doc false
  def new!(opts) do
    opts
    |> NimbleOptions.validate!(@opts_schema)
    |> finalize()
    |> as_struct!()
  end

  defp finalize(opts) do
    default_locale = Keyword.fetch!(opts, :default_locale)
    locales = Keyword.fetch!(opts, :locales)
    locales = Enum.uniq([default_locale | locales])

    route_identifier = Keyword.fetch!(opts, :route_identifier)
    path_param_key = to_string(route_identifier)

    Keyword.merge(opts, locales: locales, path_param_key: path_param_key)
  end

  defp as_struct!(opts) do
    default_struct = __MODULE__.__struct__()
    valid_keys = Map.keys(default_struct)

    config =
      opts
      |> Enum.into(%{})
      |> Map.take(valid_keys)

    Map.merge(default_struct, config)
  end
end
