defmodule Anchor.Domain.Sabotage.RecordNaming do
  @moduledoc """
  Where a generated sabotage record goes (DND-5484). Pure **Domain**, string
  functions only (no regex: `Anchor.Domain.GlobPattern` is the one compiler).

  The `records:` config (`Anchor.Domain.Sabotage.Config`):

    * `dir` — the records directory, relative to the project root; it may
      hold `{app}`, the segment after `apps/` in the mutated file's path;
    * `naming` — `:domain_date_slot` (anchor ADR 003, crew ADR 008):
      `<domain>-YYYYMMDD-<slot>.md`; or `:ticket_nn_what` (gen_saas ADR 26):
      `<TICKET>-<NN>-anchor-sabotage-run.md`, `NN` one above the highest
      number that ticket already has in that directory;
    * `domain_from` — `:module`: drop the longest `domain_strip_prefixes`
      entry the module name starts with, take the next segment, snake_case;
      or `:context_dir`: the directory under `lib/<app>/` the file sits in
      (the app's own name for a file directly in `lib/<app>/`).

  The slot is the branch, sanitized as ADR 003 says: every run of
  characters outside `[A-Za-z0-9]` becomes one `_`, trimmed at both ends,
  case kept (`dnd-5473-runner` -> `dnd_5473_runner`, `feat/umbrella-paths`
  -> `feat_umbrella_paths`). The ticket key (letters, `-`, digits, found in
  the branch case-insensitively and upper-cased: `DND-5473`) names a
  `:ticket_nn_what` file; `--slot` and `--ticket` override them.
  """

  @type naming :: :domain_date_slot | :ticket_nn_what
  @type config :: %{
          dir: String.t(),
          naming: naming(),
          domain_from: :module | :context_dir,
          domain_strip_prefixes: [String.t()]
        }
  @type slot :: %{slot: String.t(), ticket: String.t() | nil}

  @what "anchor-sabotage-run"

  @doc "The record domain of a mutated `file` / `module` under `cfg`."
  @spec domain_for(String.t(), module(), config()) :: String.t()
  def domain_for(_file, module, %{domain_from: :module} = cfg) do
    name = inspect(module)

    rest =
      cfg.domain_strip_prefixes
      |> Enum.filter(&String.starts_with?(name, &1))
      |> Enum.max_by(&byte_size/1, fn -> "" end)
      |> then(&String.replace_prefix(name, &1, ""))

    rest |> String.split(".") |> hd() |> Macro.underscore()
  end

  def domain_for(file, _module, %{domain_from: :context_dir}) do
    case file |> String.split("/") |> after_lib() do
      [app, _file] -> app
      [_app, dir | _rest] -> dir
      _other -> "lib"
    end
  end

  @doc """
  The slot of a run on `branch` (`nil` when HEAD is detached), with the
  ticket key `ticket` overrides (or the one found in the branch), and `slot`
  overriding both for the file name.
  """
  @spec slot(String.t() | nil, keyword()) :: {:ok, slot()} | {:error, :no_branch}
  def slot(branch, opts \\ []) do
    ticket = Keyword.get(opts, :ticket) || (branch && ticket_key(branch))

    case {Keyword.get(opts, :slot), ticket, branch} do
      {slot, ticket, _branch} when is_binary(slot) ->
        {:ok, %{slot: sanitize(slot), ticket: ticket}}

      {nil, ticket, branch} when is_binary(branch) ->
        {:ok, %{slot: sanitize(branch), ticket: ticket}}

      {nil, ticket, nil} when is_binary(ticket) ->
        {:ok, %{slot: sanitize(ticket), ticket: ticket}}

      {nil, nil, nil} ->
        {:error, :no_branch}
    end
  end

  @doc "The app of a path under `apps/<app>/`, else `nil`."
  @spec app_for(String.t()) :: String.t() | nil
  def app_for("apps/" <> rest) do
    case String.split(rest, "/", parts: 2) do
      [app, _rest] when app != "" -> app
      _other -> nil
    end
  end

  def app_for(_path), do: nil

  @doc "The records directory for `app` (`dir` with `{app}` filled)."
  @spec dir(config(), String.t() | nil) :: {:ok, String.t()} | {:error, :no_app}
  def dir(%{dir: dir}, app) do
    cond do
      not String.contains?(dir, "{app}") -> {:ok, dir}
      is_binary(app) -> {:ok, String.replace(dir, "{app}", app)}
      true -> {:error, :no_app}
    end
  end

  @doc """
  The record's path. `ctx`: `domain`, `app`, `date` (a `Date`), `slot` (from
  `slot/2`), and `existing_names` (the file names already in the directory).
  """
  @spec path(config(), map()) :: {:ok, String.t()} | {:error, :no_ticket | :no_app}
  def path(cfg, ctx) do
    with {:ok, dir} <- dir(cfg, ctx.app),
         {:ok, name} <- name(cfg.naming, ctx) do
      {:ok, Path.join(dir, name)}
    end
  end

  @doc "`text` with every run of characters outside `[A-Za-z0-9]` one `_`, trimmed."
  @spec sanitize(String.t()) :: String.t()
  def sanitize(text) do
    text
    |> String.to_charlist()
    |> Enum.chunk_by(&alnum?/1)
    |> Enum.map_join(fn [c | _] = run -> if alnum?(c), do: List.to_string(run), else: "_" end)
    |> String.trim("_")
  end

  defp name(:domain_date_slot, ctx),
    do: {:ok, "#{ctx.domain}-#{Calendar.strftime(ctx.date, "%Y%m%d")}-#{ctx.slot.slot}.md"}

  defp name(:ticket_nn_what, %{slot: %{ticket: nil}}), do: {:error, :no_ticket}

  defp name(:ticket_nn_what, %{slot: %{ticket: ticket}} = ctx) do
    taken =
      ctx.existing_names
      |> Enum.flat_map(fn name -> number(name, ticket <> "-") end)
      |> Enum.max(fn -> 0 end)

    nn = (taken + 1) |> Integer.to_string() |> String.pad_leading(2, "0")
    {:ok, "#{ticket}-#{nn}-#{@what}.md"}
  end

  defp number(name, prefix) do
    with ^prefix <> rest <- name,
         [digits, _what] <- String.split(rest, "-", parts: 2),
         {n, ""} <- Integer.parse(digits) do
      [n]
    else
      _other -> []
    end
  end

  defp after_lib(["lib" | rest]), do: rest
  defp after_lib([_segment | rest]), do: after_lib(rest)
  defp after_lib([]), do: []

  # A ticket key: a run of letters, `-`, a run of digits, as whole tokens.
  @doc "The first ticket key in `text` (`dnd-12-x` -> `DND-12`), upper-cased, else `nil`."
  @spec ticket_key(String.t()) :: String.t() | nil
  def ticket_key(text) do
    tokens =
      text
      |> String.to_charlist()
      |> Enum.chunk_by(&alnum?/1)
      |> Enum.map(&List.to_string/1)

    tokens
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.find_value(fn
      [letters, "-", digits] -> if letters?(letters) and digits?(digits), do: key(letters, digits)
      _other -> nil
    end)
  end

  defp key(letters, digits), do: String.upcase(letters) <> "-" <> digits

  defp letters?(text), do: text != "" and text |> String.to_charlist() |> Enum.all?(&letter?/1)

  defp digits?(text),
    do: text != "" and text |> String.to_charlist() |> Enum.all?(&(&1 in ?0..?9))

  defp letter?(c), do: c in ?a..?z or c in ?A..?Z
  defp alnum?(c), do: letter?(c) or c in ?0..?9
end
