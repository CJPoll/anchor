defmodule Anchor.Domain.AttributeNodeTest do
  # Domain: an attribute's name is never code, only its value is.
  use ExUnit.Case, async: true

  alias Anchor.Domain.AttributeNode

  defp ast(source), do: Code.string_to_quoted!(source)

  describe "children/1" do
    test "a set attribute named like a special form has its value as its one child" do
      assert {:@, _meta, [{:quote, _name_meta, [_value]}]} = node = ast("@quote Other.Mod")
      assert AttributeNode.children(node) == [ast("Other.Mod")]
    end

    test "a read attribute named like a special form has no children" do
      assert {:@, _meta, [{:quote, _name_meta, nil}]} = node = ast("@quote")
      assert AttributeNode.children(node) == []
    end

    test "an @ node of any other shape keeps its arguments" do
      node = {:@, [], [1, 2]}
      assert AttributeNode.children(node) == [1, 2]
    end
  end

  describe "without_name/1" do
    test "a set attribute becomes an @ node over its value alone" do
      assert {:@, _meta, [value]} = AttributeNode.without_name(ast("@use Other.Mod"))
      assert value == ast("Other.Mod")
    end

    test "a read attribute becomes an @ node with no children" do
      assert {:@, _meta, []} = AttributeNode.without_name(ast("@def"))
    end

    test "a node that is not an attribute is returned unchanged" do
      node = ast("use Other.Mod")
      assert AttributeNode.without_name(node) == node
    end
  end
end
