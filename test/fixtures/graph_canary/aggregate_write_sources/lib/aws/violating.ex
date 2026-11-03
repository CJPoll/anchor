defmodule Aws.Violating do
  @moduledoc "An unresolved write, and a transaction that calls a fun parameter."
  alias Aws.Repo

  def save(record), do: Repo.insert(record)

  def run(fun), do: Repo.transaction(fn -> fun.() end)
end
