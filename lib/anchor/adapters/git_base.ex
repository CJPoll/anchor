defmodule Anchor.Adapters.GitBase do
  @moduledoc """
  Behaviour for reading a file as it is on a base ref, the **Side Effect**
  port (ADR 001) behind `mix anchor.graph --base REF` (DND-5441): GREW is
  judged against the base branch's copy of a baseline, never the branch's
  own. The real adapter is `Anchor.Adapters.GitShow`; tests double it with
  Hammox (`Anchor.GitBaseMock`).

  `show/3` returns the file's bytes at `ref`, `{:error, :absent}` when `ref`
  resolves but holds no such file (a first landing), `{:error, :bad_ref}` for
  a ref Anchor refuses to pass to git (`Anchor.Domain.Baseline.valid_ref?/1`),
  or `{:error, {:git, status, output}}` for any other failure, such as a ref
  that does not resolve. A failure is never read as "no growth".
  """

  @callback show(root :: Path.t(), ref :: String.t(), path :: Path.t()) ::
              {:ok, binary()}
              | {:error, :absent | :bad_ref | {:git, non_neg_integer(), String.t()}}
end
