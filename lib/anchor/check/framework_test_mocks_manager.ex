defmodule Anchor.Check.FrameworkTestMocksManager do
  use Anchor.Check.Base,
    detector: Anchor.Domain.Checks.FrameworkTestMocksManager,
    category: :design,
    explanations: [
      check: """
      A Framework test mocks the Manager: it asserts the Manager function is
      called with the expected arguments and that the entry point returns the
      expected value. Every test file the rule selects must set at least one
      expectation (`expect`, never `stub`) on a double whose name matches the
      rule's `mock_patterns`, and must verify it (`setup :verify_on_exit!`).

      Verification is what makes the static check sound: an expectation the
      endpoint never reaches fails the test, so the Manager's seam must be
      bound to the double for the test to pass.

      ## Examples

      Avoid:
      ```elixir
      test "searches", %{conn: conn} do
        assert conn |> post("/search", q: "x") |> json_response(200)
      end
      ```

      Prefer:
      ```elixir
      setup :verify_on_exit!

      test "hands the query to search/1", %{conn: conn} do
        expect(SearchMock, :search, fn "x" -> {:ok, []} end)
        assert conn |> post("/search", q: "x") |> json_response(200) == []
      end
      ```
      """
    ]
end
