defmodule Anchor.Adapters.GitChangeSource do
  @moduledoc """
  Reads a working tree's changes with git, the **Side Effect** adapter
  (ADR 001) behind `Anchor.Adapters.ChangeSource` (DND-5472).

  Git runs with `System.cmd/3`: argv only, never a shell, so a `--base` value
  is never interpolated into a command line, and a ref is passed after
  `--end-of-options` so it cannot be read as an option. It only reads:
  `GIT_OPTIONAL_LOCKS=0` stops `git diff` refreshing the index.

  Commands, each run in `root`:

    * `git rev-parse --is-inside-work-tree`;
    * `git rev-parse --verify --quiet --end-of-options <ref>^{commit}`, then
      `git merge-base <sha> HEAD`;
    * `git diff --unified=0 --no-color --no-ext-diff --no-textconv --no-renames
      --relative --src-prefix=a/ --dst-prefix=b/ <sha> --` (`--relative`: paths
      relative to `root`, the same base `ls-files` uses; the prefixes are set
      so a user's `diff.noprefix` cannot change the text);
    * `git ls-files -z --others --exclude-standard -- *.ex`.

  `diff` and `ls-files` keep git's stderr out of their output, so a warning
  can never read as diff text; on a failure git's own message is on stderr and
  the error carries the command, its exit status and its stdout.
  """

  @behaviour Anchor.Adapters.ChangeSource

  @diff_args ~w(diff --unified=0 --no-color --no-ext-diff --no-textconv --no-renames --relative
                --src-prefix=a/ --dst-prefix=b/)

  @impl Anchor.Adapters.ChangeSource
  def merge_base(root, ref) do
    with :ok <- work_tree(root),
         {:ok, sha} <- resolve(root, ref) do
      case git(root, ["merge-base", sha, "HEAD"], true) do
        {out, 0} -> {:ok, String.trim(out)}
        {_out, 1} -> {:error, {:no_merge_base, ref}}
        {out, status} -> {:error, {:git_failed, ["merge-base", sha, "HEAD"], status, out}}
      end
    end
  end

  @impl Anchor.Adapters.ChangeSource
  def diff(root, sha) do
    args = @diff_args ++ [sha, "--"]

    case git(root, args, false) do
      {out, 0} -> {:ok, out}
      {out, status} -> {:error, {:git_failed, args, status, out}}
    end
  end

  @impl Anchor.Adapters.ChangeSource
  def untracked(root) do
    args = ["ls-files", "-z", "--others", "--exclude-standard", "--", "*.ex"]

    case git(root, args, false) do
      {out, 0} -> {:ok, String.split(out, <<0>>, trim: true)}
      {out, status} -> {:error, {:git_failed, args, status, out}}
    end
  end

  @impl Anchor.Adapters.ChangeSource
  def read(root, path), do: File.read(Path.join(root, path))

  defp work_tree(root) do
    with true <- File.dir?(root),
         {"true\n", 0} <- git(root, ["rev-parse", "--is-inside-work-tree"], true) do
      :ok
    else
      _not_a_work_tree -> {:error, :not_a_work_tree}
    end
  end

  defp resolve(root, ref) do
    case git(
           root,
           ["rev-parse", "--verify", "--quiet", "--end-of-options", ref <> "^{commit}"],
           true
         ) do
      {out, 0} -> {:ok, String.trim(out)}
      {_out, _status} -> {:error, {:no_merge_base, ref}}
    end
  end

  defp git(root, args, merge_stderr?) do
    System.cmd("git", args,
      cd: root,
      stderr_to_stdout: merge_stderr?,
      env: [{"GIT_OPTIONAL_LOCKS", "0"}]
    )
  end
end
