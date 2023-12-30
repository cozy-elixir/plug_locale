defmodule PlugLocale.Browser.AcceptLanguage do
  @moduledoc false

  def extract_locales(line) do
    line
    |> split_languages()
    |> Stream.map(&parse_language/1)
    |> Stream.reject(&is_nil(&1.tag))
    |> Enum.sort(&(&1.quality > &2.quality))
    |> Enum.map(& &1.tag)
  end

  defp split_languages(line) do
    String.split(line, ",")
  end

  defp parse_language(language) do
    Regex.named_captures(~r/^\s?(?<tag>[\w\-]+)(?:;q=(?<quality>[\d\.]+))?$/i, language)
    |> case do
      %{"tag" => tag, "quality" => quality} ->
        quality =
          case Float.parse(quality) do
            {val, _} -> val
            _ -> 1.0
          end

        %{tag: tag, quality: quality}

      _ ->
        %{tag: nil, quality: nil}
    end
  end
end
