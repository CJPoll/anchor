defmodule Aws.Compliant do
  @moduledoc "One transaction whose every write traces to a schema."
  alias Aws.Repo
  alias Aws.Thread

  def create(title), do: Repo.transaction(fn -> Repo.insert(%Thread{title: title}) end)
end
