defmodule StubOnWeb.Parsers.URLENCODED do
  @moduledoc """
  Parses urlencoded request body, and optionally copies the raw body

  Copies raw body to `:raw_body` private assign when `:copy_raw_body`
  private assign is true
  """

  @behaviour Plug.Parsers
  alias Plug.Conn

  def parse(conn, "application", "x-www-form-urlencoded", _headers, opts) do
    case Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        Plug.Conn.Utils.validate_utf8!(body, "urlencoded body")
        decoded_body = Plug.Conn.Query.decode(body)
        conn = if conn.private[:copy_raw_body] do Plug.Conn.put_private(conn, :raw_body, body) else conn end
        {:ok, decoded_body, conn}
      {:more, _data, conn} ->
        {:error, :too_large, conn}
    end
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end
end

defmodule StubOnWeb.Parsers.JSON do
  @moduledoc """
  Parses JSON request body.

  JSON arrays are parsed into a `"_json"` key to allow
  proper param merging.

  An empty request body is parsed as an empty map.

  Copies raw body to `:raw_body` private assign when `:copy_raw_body`
  private assign is true
  """

  @behaviour Plug.Parsers
  import Plug.Conn

  def parse(conn, "application", subtype, _headers, opts) do
    if subtype == "json" || String.ends_with?(subtype, "+json") do
      decoder = Keyword.get(opts, :json_decoder) ||
                  raise ArgumentError, "JSON parser expects a :json_decoder option"
      conn
      |> read_body(opts)
      |> decode(decoder)
    else
      {:next, conn}
    end
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  defp decode({:more, _, conn}, _decoder) do
    {:error, :too_large, conn}
  end

  defp decode({:ok, "", conn}, _decoder) do
    {:ok, %{}, conn}
  end

  defp decode({:ok, body, conn}, decoder) do
    conn = if conn.private[:copy_raw_body] do Plug.Conn.put_private(conn, :raw_body, body) else conn end
    case decoder.decode!(body) do
      terms when is_map(terms) ->
        {:ok, terms, conn}
      terms ->
        {:ok, %{"_json" => terms}, conn}
    end
  rescue
    e -> raise Plug.Parsers.ParseError, exception: e
  end
end
