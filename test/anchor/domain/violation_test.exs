defmodule Anchor.Domain.ViolationTest do
  # Domain data type: a violation is `{line, trigger, message}`, free of any
  # Credo type. `Anchor.Check.Base` is what maps it to a `Credo.Issue`.
  use ExUnit.Case, async: true

  alias Anchor.Domain.Violation

  describe "struct" do
    test "carries line, trigger, and message" do
      violation = %Violation{line: 12, trigger: "MyApp.Repo", message: "forbidden"}

      assert violation.line == 12
      assert violation.trigger == "MyApp.Repo"
      assert violation.message == "forbidden"
    end

    test "line and trigger are optional (default nil); message is required" do
      violation = %Violation{message: "something"}

      assert violation.line == nil
      assert violation.trigger == nil
      assert violation.message == "something"
    end

    test "building without the required :message key raises" do
      assert_raise ArgumentError, fn ->
        # `struct!/2` enforces @enforce_keys; wrapped so the missing-key raise is
        # asserted rather than a compile-time error.
        struct!(Violation, line: 1)
      end
    end
  end
end
