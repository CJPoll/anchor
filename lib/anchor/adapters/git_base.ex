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
                 | {:line, pos_integer(), :invalid_utf8}
                 | {:git, non_neg_integer() | :enoent, String.t()}}
end
