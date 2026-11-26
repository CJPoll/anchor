defmodule Anchor.Domain.Checks.FrameworkTestMocksManagerTest do
  # A Framework test file expects on a manager double and verifies
  # it. Pure Domain: sources are parsed with columns, as `Credo.Code.ast/1`
  # does.
  #
  # Sabotage record:
  #   ../../../sabotage_records/framework_test_mocks_manager-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.FrameworkTestMocksManager, as: Check

  @rule %{mock_patterns: ["*.Managers.*Mock", "MyApp.ContactsMock"]}

  defp detect(source, rules \\ [@rule]) do
    source
    |> Code.string_to_quoted!(columns: true)
    |> Check.detect_violations(rules)
  end

  defp test_file(body) do
    """
    defmodule AppWeb.SearchControllerTest do
      use AppWeb.ConnCase, async: true

    #{body}
    end
    """
  end

  describe "a file that expects on a manager double and verifies it" do
    test "P1: an aliased double, a bare expect and setup :verify_on_exit!" do
      source =
        test_file("""
          import Hammox
          alias App.Search.Managers.SearchMock

          setup :verify_on_exit!

          test "searches", %{conn: conn} do
            expect(SearchMock, :search, fn "x" -> {:ok, []} end)
            post(conn, "/search", q: "x")
          end
        """)

      assert detect(source) == []
    end

    test "P2: Mox.expect and Hammox.expect with a count, fully named doubles" do
      for lib <- ["Mox", "Hammox"] do
        source =
          test_file("""
            setup :verify_on_exit!

            test "refuses" do
              #{lib}.expect(App.Search.Managers.SearchMock, :search, 0, fn _ -> nil end)
            end
          """)

        assert detect(source) == [], lib
      end
    end

    test "P3: a piped expect, and a chain of them, name the pipe's head" do
      for body <- [
            "SearchMock |> expect(:search, fn _ -> :ok end)",
            "SearchMock |> expect(:a, fn _ -> :ok end) |> expect(:b, 2, fn _ -> :ok end)",
            "SearchMock |> Mox.expect(:a, fn _ -> :ok end)",
            "expect(SearchMock, :a, fn _ -> :ok end) |> expect(:b, fn _ -> :ok end)"
          ] do
        source =
          test_file("""
            alias App.Search.Managers.SearchMock
            setup :verify_on_exit!
            test "t", do: #{body}
          """)

        assert detect(source) == [], body
      end
    end

    test "P4: every way to verify: setup lists, the library tuple, calls" do
      for verify <- [
            "setup [:set_mox_from_context, :verify_on_exit!]",
            "setup {Mox, :verify_on_exit!}",
            "setup {Hammox, :verify_on_exit!}",
            "setup do\n verify_on_exit!()\n end",
            "setup do\n Mox.verify_on_exit!()\n end",
            "setup context do\n Hammox.verify_on_exit!(context)\n end",
            "test \"v\", do: verify!()",
            "test \"v\", do: Mox.verify!(MyApp.ContactsMock)",
            "test \"v\", do: verify!(MyApp.ContactsMock)",
            "test \"v\", do: MyApp.ContactsMock |> verify!()",
            "test \"v\", do: MyApp.ContactsMock |> Hammox.verify!()",
            "setup ctx do\n ctx |> verify_on_exit!()\n end"
          ] do
        source =
          test_file("""
            #{verify}
            test "t", do: expect(MyApp.ContactsMock, :list, fn -> [] end)
          """)

        assert detect(source) == [], verify
      end
    end

    test "P5: an expectation in a private helper of the file counts" do
      source =
        test_file("""
          setup :verify_on_exit!
          defp expect_search(answer), do: expect(App.Search.Managers.SearchMock, :search, fn _ -> answer end)
          test "t", do: expect_search(:ok)
        """)

      assert detect(source) == []
    end
  end

  describe "a file that does not mock the manager" do
    test "N1: no expectation at all is one violation at line 1, with Fix" do
      source =
        test_file("""
          test "searches", %{conn: conn} do
            post(conn, "/search", q: "x")
          end
        """)

      assert [violation] = detect(source)
      assert violation.line == 1
      assert violation.trigger == "expect"

      # The whole message: with no other double and no unresolved site, the
      # finding adds no clause for either.
      assert violation.message ==
               "Framework test sets no expectation on a manager double (a module matching " <>
                 "*.Managers.*Mock, MyApp.ContactsMock). Fix: " <> Check.shape(@rule)
    end

    test "N2: a stub is not an expectation" do
      source =
        test_file("""
          setup :verify_on_exit!
          test "t" do
            stub(App.Search.Managers.SearchMock, :search, fn _ -> :ok end)
            Mox.stub(App.Search.Managers.SearchMock, :search, fn _ -> :ok end)
            stub_with(App.Search.Managers.SearchMock, App.Search.Managers.Search)
          end
        """)

      assert [%{trigger: "expect"}] = detect(source)
    end

    test "N3: an expectation on a double no mock_patterns entry names is named in the finding" do
      source =
        test_file("""
          setup :verify_on_exit!
          test "t", do: expect(App.Adapters.RepoMock, :all, fn _ -> [] end)
        """)

      assert [violation] = detect(source)

      assert violation.message =~
               "its expectations name only App.Adapters.RepoMock, which no mock_patterns entry matches"
    end

    test "N4: an expectation with no verification is reported at the expectation" do
      source =
        test_file("""
          test "t" do
            expect(App.Search.Managers.SearchMock, :search, fn _ -> :ok end)
          end
        """)

      assert [violation] = detect(source)
      assert violation.trigger == "verify_on_exit!"
      assert violation.line == 5

      assert violation.message =~
               "Framework test expects on App.Search.Managers.SearchMock but never verifies"
    end

    test "N5: a double that is not a module name fails closed and is named" do
      for {expr, shown} <- [
            {"expect(mock, :search, fn _ -> :ok end)", "line 6 `mock`"},
            {"expect(@mock, :search, fn _ -> :ok end)", "line 6 `@mock`"},
            {"expect(mock(), :search, fn _ -> :ok end)", "line 6 `mock()`"},
            {"expect(__MODULE__, :search, fn _ -> :ok end)", "line 6 `__MODULE__`"},
            {"mock |> expect(:search, fn _ -> :ok end)", "line 6 `mock`"},
            {"expect(App.Search |> mock_for(), :search, fn _ -> :ok end)",
             "line 6 `App.Search |> mock_for()`"}
          ] do
        source =
          test_file("""
            setup :verify_on_exit!
            @mock App.Search.Managers.SearchMock
            test "t", do: #{expr}
          """)

        assert [violation] = detect(source), expr
        assert violation.message =~ "the double of 1 expectation(s) is not a module name", expr
        assert violation.message =~ shown, expr
      end
    end

    test "N6: a bare expect is not Mox's when the file defines its own expect" do
      source =
        test_file("""
          setup :verify_on_exit!
          defp expect(mock, name, fun), do: {mock, name, fun}
          test "t", do: expect(App.Search.Managers.SearchMock, :search, fn _ -> :ok end)
        """)

      assert [%{trigger: "expect"}] = detect(source)
    end

    test "N6b: the file's own expect shadows only its arity; a guard and defaults count" do
      call = "expect(App.Search.Managers.SearchMock, :search, fn _ -> :ok end)"

      for {definition, verdict} <- [
            {"defp expect(m, n, f) when is_atom(m), do: {m, n, f}", :shadowed},
            {"defp expect(m, n \\\\ :a, f \\\\ nil), do: {m, n, f}", :shadowed},
            {"defp expect(m), do: m", :mox},
            {"defp expect, do: :none", :mox},
            {"defmacro expect(m, n, f), do: {m, n, f}", :shadowed},
            {"defmacrop expect(m, n, f), do: {m, n, f}", :shadowed},
            {"def unquote(:other)(m), do: m", :mox}
          ] do
        source =
          test_file("""
            setup :verify_on_exit!
            #{definition}
            test "t", do: #{call}
          """)

        expected = if verdict == :shadowed, do: ["expect"], else: []
        assert Enum.map(detect(source), & &1.trigger) == expected, definition
      end
    end

    test "N13: a chain of expectations names its head's double at every link" do
      for chain <- [
            "App.Adapters.RepoMock |> expect(:a, fn -> 1 end) |> expect(:b, fn -> 2 end)",
            "expect(App.Adapters.RepoMock, :a, fn -> 1 end) |> expect(:b, fn -> 2 end)"
          ] do
        source = test_file("setup :verify_on_exit!\ntest \"t\", do: #{chain}")

        assert [violation] = detect(source), chain

        assert violation.message ==
                 "Framework test sets no expectation on a manager double (a module matching " <>
                   "*.Managers.*Mock, MyApp.ContactsMock); its expectations name only " <>
                   "App.Adapters.RepoMock, which no mock_patterns entry matches. Fix: " <>
                   Check.shape(@rule),
               chain
      end
    end

    test "N14: a piped expect has the arity of its call with the pipe's head" do
      source =
        test_file("""
          setup :verify_on_exit!
          defp expect(m, n, f), do: {m, n, f}
          test "t", do: App.Search.Managers.SearchMock |> expect(:search, fn _ -> :ok end)
        """)

      assert [%{trigger: "expect"}] = detect(source)
    end

    test "N15: a setup list without the verifier does not verify" do
      source =
        test_file("""
          setup [:set_mox_from_context, :insert_user]
          test "t", do: expect(App.Search.Managers.SearchMock, :search, fn _ -> :ok end)
        """)

      assert [%{trigger: "verify_on_exit!"}] = detect(source)
    end

    test "N16: verify!/1 verifies only the double it names" do
      for verify <- [
            "Mox.verify!(App.Adapters.RepoMock)",
            "verify!(App.Adapters.RepoMock)",
            "Hammox.verify!(mock)",
            "App.Adapters.RepoMock |> verify!()",
            "App.Adapters.RepoMock |> Mox.verify!()"
          ] do
        source =
          test_file("""
            test "t" do
              expect(App.Search.Managers.SearchMock, :search, fn _ -> :ok end)
              #{verify}
            end
          """)

        assert [%{trigger: "verify_on_exit!"}] = detect(source), verify
      end
    end

    test "N17: the file's own verifier, or a definition's head, does not verify" do
      for definitions <- [
            "defp verify!(conn), do: conn",
            "defp verify!, do: :ok\ntest \"v\", do: verify!()",
            "def verify_on_exit!(context), do: context\nsetup :verify_on_exit!",
            "defmacro verify_on_exit!, do: :ok\nsetup do\n verify_on_exit!()\n end"
          ] do
        source =
          test_file("""
            #{definitions}
            test "t", do: expect(App.Search.Managers.SearchMock, :search, fn _ -> :ok end)
          """)

        assert [%{trigger: "verify_on_exit!"}] = detect(source), definitions
      end
    end

    test "N18: a local verify_on_exit! of another arity leaves setup's call Mox's" do
      source =
        test_file("""
          defp verify_on_exit!(a, b), do: {a, b}
          setup :verify_on_exit!
          test "t", do: expect(App.Search.Managers.SearchMock, :search, fn _ -> :ok end)
        """)

      assert detect(source) == []
    end

    test "P6: a pipe into anything else is walked as code, not as a verifier" do
      source =
        test_file("""
          alias App.Search.Managers.SearchMock
          setup :verify_on_exit!
          test "t", %{conn: conn} do
            conn |> post("/search", q: expect(SearchMock, :search, fn _ -> :ok end)) |> json_response(200)
            conn |> next
          end
        """)

      assert detect(source) == []
    end

    test "N19: a piped verifier the file defines itself, at the piped arity, does not verify" do
      source =
        test_file("""
          defp verify_on_exit!(context), do: context
          setup ctx do
            ctx |> verify_on_exit!()
          end
          test "t", do: expect(App.Search.Managers.SearchMock, :search, fn _ -> :ok end)
        """)

      assert [%{trigger: "verify_on_exit!"}] = detect(source)
    end

    test "N12: an Erlang atom is no module name, so it fails closed" do
      source =
        test_file("""
          setup :verify_on_exit!
          test "t", do: expect(:search_mock, :search, fn _ -> :ok end)
        """)

      assert [violation] = detect(source, [%{mock_patterns: ["*_mock"]}])
      assert violation.message =~ "line 5 `:search_mock`"
    end

    test "N7: an expect qualified by another module, or of the wrong arity, is not an expectation" do
      for expr <- [
            "Other.expect(App.Search.Managers.SearchMock, :search, fn _ -> :ok end)",
            "expect(App.Search.Managers.SearchMock, :search)",
            "expect(App.Search.Managers.SearchMock, :search, 1, 2, fn _ -> :ok end)",
            "App.Search.Managers.SearchMock |> expect(:search)"
          ] do
        source = test_file("setup :verify_on_exit!\ntest \"t\", do: #{expr}")
        assert [%{trigger: "expect"}] = detect(source), expr
      end
    end

    test "N8: an alias of another module named Mox does not verify or expect as Mox" do
      source =
        test_file("""
          alias App.Fake.Mox
          setup {Mox, :verify_on_exit!}
          test "t", do: Mox.expect(App.Search.Managers.SearchMock, :search, fn _ -> :ok end)
        """)

      assert [%{trigger: "expect"}] = detect(source)
    end

    test "N9: a verifier that is not Mox's or Hammox's does not verify" do
      source =
        test_file("""
          setup {Other, :verify_on_exit!}
          test "t" do
            Other.verify!()
            expect(App.Search.Managers.SearchMock, :search, fn _ -> :ok end)
          end
        """)

      assert [%{trigger: "verify_on_exit!"}] = detect(source)
    end

    test "N10: a file with no module is reported" do
      assert [%{trigger: "expect"}] = detect("IO.puts(:hi)")
    end

    test "N11: each rule is judged on its own patterns" do
      source =
        test_file("""
          setup :verify_on_exit!
          test "t", do: expect(MyApp.ContactsMock, :list, fn -> [] end)
        """)

      rules = [@rule, %{mock_patterns: ["*.Managers.*Mock"]}]
      assert [violation] = detect(source, rules)
      assert violation.message =~ "(a module matching *.Managers.*Mock)"
    end
  end

  describe "shape/1" do
    test "names the rule's patterns" do
      assert Check.shape(@rule) =~ "(*.Managers.*Mock, MyApp.ContactsMock)"
      assert Check.shape(@rule) =~ "setup :verify_on_exit!"
    end
  end
end
