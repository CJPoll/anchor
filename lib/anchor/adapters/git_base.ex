defmodule Anchor.Adapters.GitBase do
  @moduledoc """
  Behaviour for reading a file as it is on a base ref, the **Side Effect**
  port (ADR 001) behind `mix anchor.graph --base REF` (DND-5441): GREW is
  judged against the base branch's copy of a baseline, never the branch's
  own. The real adapter is `Anchor.Adapters.GitShow`; tests double it with
  Hammox (`Anchor.GitBaseMock`).

  `show/3` returns the file's entries at `ref`, parsed by
  `Anchor.Domain.Baseline.parse/1` (ADR 001: never the raw bytes),
  `{:error, :absent}` when `ref` resolves but holds no such file (a first
  landing), `{:error, {:line, n, :invalid_utf8}}` for a line that is not
  UTF-8, `{:error, :bad_ref}` for a ref Anchor refuses to pass to git
  (`Anchor.Domain.Baseline.valid_ref?/1`), or `{:error, {:git, status,
  output}}` for any other failure, such as a ref that does not resolve or no
  git to run. A failure is never read as "no growth".
  """

  @callback show(root :: Path.t(), ref :: String.t(), path :: Path.t()) ::
              {:ok, [String.t()]}
              | {:error,
                 :absent
                 | :bad_ref
                 | :outside_root
                 | {:symlink, String.t()}
                 | {:line, pos_integer(), :invalid_utf8}
                 | {:git, non_neg_integer() | :enoent, String.t()}}

  @doc """
  The graph rules of the config at `path` as it is on `ref` (DND-5629): the
  base copy of each baseline is found by its rule's id there. `{:error,
  :absent}` when the ref resolves and has no file there; a symlink is refused
  as `show/3` refuses one; a document the config parser rejects is its error.
  """
  @callback rules(root :: Path.t(), ref :: String.t(), path :: Path.t()) ::
              {:ok, [map()]}
              | {:error,
                 :absent
                 | :bad_ref
                 | :outside_root
                 | {:symlink, String.t()}
                 | {:git, non_neg_integer() | :enoent, String.t()}
                 | {:yaml, String.t()}
                 | {:invalid_config, term()}
                 | {:invalid_rule, term()}}
end
