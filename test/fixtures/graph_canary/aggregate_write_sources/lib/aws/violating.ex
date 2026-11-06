defmodule Aws.Violating do
  @moduledoc "An unresolved write, and transactions that call a fun parameter and an unlisted dependency."
  alias Aws.Repo

  def save(record), do: Repo.insert(record)

  def run(fun), do: Repo.transaction(fn -> fun.() end)

  def ask(server), do: Repo.transaction(fn -> GenServer.call(server, :save) end)
end
