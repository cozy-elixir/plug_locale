defmodule PlugLocale.Header.Config do
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
    cast_locale_by: [
      type: {:or, [nil, {:fun, 1}]},
      default: nil
    ],
    header_name: [
      type: :string,
      default: "x-client-locale"
    ],
    assign_key: [
      type: :atom,
      default: :locale
    ]
  ]

  defstruct Keyword.keys(@opts_schema)

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

    Keyword.merge(opts, locales: locales)
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
