defmodule Anchor.Adapters.RecordFile do
  @moduledoc """
  The sabotage record files (DND-5484), the **Side Effect** adapter (ADR 001)
  behind `Anchor.Adapters.RecordStore`. It writes only record files: `create`
  opens with `:exclusive`, so an existing record is never overwritten, and
  `append` only adds. It never writes a README, and stages or commits nothing.
  `write_report` writes a scan report and its `.etf` (DND-5490), overwriting
  both: a report is a build output, never a record.
  """

  @behaviour Anchor.Adapters.RecordStore

  @impl Anchor.Adapters.RecordStore
  def list(root, dir_glob) do
    root
    |> Path.join(dir_glob)
    |> Path.join("*.md")
    |> Path.wildcard()
    |> Enum.reject(&(Path.basename(&1) == "README.md"))
    |> Enum.map(&Path.relative_to(&1, root))
    |> Enum.sort()
  end

  @impl Anchor.Adapters.RecordStore
  def read(root, path), do: File.read(Path.join(root, path))

  @impl Anchor.Adapters.RecordStore
  def create(root, path, content) do
    full = Path.join(root, path)

    with :ok <- File.mkdir_p(Path.dirname(full)) do
      File.write(full, content, [:exclusive])
    end
  end

  @impl Anchor.Adapters.RecordStore
  def append(root, path, content) do
    full = Path.join(root, path)

    case File.stat(full) do
      {:ok, %File.Stat{type: :regular}} -> File.write(full, "\n" <> content, [:append])
      {:ok, %File.Stat{}} -> {:error, :eisdir}
      {:error, posix} -> {:error, posix}
    end
  end

  @impl Anchor.Adapters.RecordStore
  def write_report(root, path, markdown, term) do
    full = Path.expand(path, root)
    etf = Path.rootname(full) <> ".etf"

    with :ok <- File.mkdir_p(Path.dirname(full)),
         :ok <- File.write(full, markdown),
         :ok <- File.write(etf, term) do
      {:ok, [full, etf]}
    end
  end
end
