defmodule Aws.Thread do
  @moduledoc "A real Ecto schema."
  use Ecto.Schema

  schema "threads" do
    field(:title, :string)
  end
end
