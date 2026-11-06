defmodule AggNone.Thread do
  @moduledoc "A real Ecto schema, which declare: none denies."
  use Ecto.Schema

  schema "threads" do
    field(:title, :string)
  end
end
