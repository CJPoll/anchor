defmodule Anchor.Domain.GraphRules.AggregateDeclarations do
  @moduledoc """
  The `aggregate_declarations` graph rule (DND-5476): every aggregate
  declaration names something, and every schema and table belongs to at most
  one aggregate — a **Domain** module (ADR 001). Pure, over the run's
  `Anchor.Domain.Model`, whose `aggregates` index
  (`Anchor.Domain.Aggregates.Index`) holds what it reports.

  Each issue of the index is one violation, at its site: an issue of the
  `.anchor.yml` section is always reported; one of a module's
  `@anchor_aggregate` is reported when the rule's selector (`bucket`, `paths`
  or `pattern`) selects that module. The key is
  `<id>|<site>|<kind> <aggregates, sorted, joined by ","> <subject>`, where the
  site is `.anchor.yml` or the declaring module: no line numbers.

  When no aggregate is declared at all, the rule checks nothing, and says so
  in one violation on the config (the Anchor fail-closed convention).

  Every message ends with `Fix:`, the advice and the declaration shape
  (`shape/1`).
  """

  @behaviour Anchor.Domain.GraphRule
  @behaviour Anchor.Domain.RuleShape

  alias Anchor.Domain.Aggregates.Config
  alias Anchor.Domain.Aggregates.DeclarationIssue
  alias Anchor.Domain.Aggregates.Index
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.Violation
  alias Anchor.Domain.ViolationKey

  @config_file ".anchor.yml"

  @impl Anchor.Domain.GraphRule
  def rule_type, do: :aggregate_declarations

  @impl Anchor.Domain.RuleShape
  def shape(_rule),
    do: Config.shape() <> ", or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]"

  @impl Anchor.Domain.GraphRule
  def check(%Model{aggregates: %Index{} = index} = model, rule) do
    selected = model |> GraphRules.select(rule) |> MapSet.new()

    issues =
      index.issues
      |> Enum.filter(&in_scope?(&1.site, selected))
      |> Enum.map(&violation(&1, model, rule))

    if Index.declared(index) == 0,
      do: issues ++ [checks_nothing(model, rule)],
      else: issues
  end

  defp in_scope?(:config, _selected), do: true

  defp in_scope?({:attribute, module, _file, _line}, selected),
    do: MapSet.member?(selected, module)

  defp checks_nothing(model, rule) do
    %Violation{
      filename: config_file(model),
      line: nil,
      trigger: "aggregate_declarations",
      rule_id: Map.get(rule, :id),
      key: ViolationKey.graph_key(rule, @config_file, "checks nothing"),
      message:
        "aggregate_declarations checks nothing: no aggregate is declared in .anchor.yml or by " <>
          "an @anchor_aggregate attribute. Fix: declare one or remove the rule: #{shape(rule)}"
    }
  end

  defp violation(%DeclarationIssue{} = issue, model, rule) do
    {file, line, site} = site(issue.site, model)

    %Violation{
      filename: file,
      line: line,
      trigger: subject(issue),
      rule_id: Map.get(rule, :id),
      key:
        ViolationKey.graph_key(rule, site, "#{issue.kind} #{aggregates(issue)} #{subject(issue)}"),
      message: message(issue) <> ": " <> shape(rule)
    }
  end

  defp site(:config, model), do: {config_file(model), nil, @config_file}

  defp site({:attribute, module, file, line}, model),
    do: {file || config_file(model), line, inspect(module)}

  defp config_file(%Model{config: %{path: path}}) when is_binary(path), do: path
  defp config_file(_model), do: @config_file

  defp message(%DeclarationIssue{kind: :claimed_twice} = issue) do
    "#{noun(issue.subject)} #{subject(issue)} is claimed by " <>
      "#{and_list(issue.aggregates)}. Fix: list it in exactly one aggregate; the other " <>
      "reaches it through an outbox row consumed by the owner"
  end

  defp message(%DeclarationIssue{kind: kind} = issue)
       when kind in [:unknown_schema, :unknown_owner] do
    "#{subject(issue)} in aggregate #{hd(issue.aggregates)} names no module in this " <>
      "project. Fix: correct the module name or remove it"
  end

  defp message(%DeclarationIssue{kind: :not_a_schema} = issue) do
    "#{subject(issue)} in aggregate #{hd(issue.aggregates)} is not an Ecto schema " <>
      "(no __schema__/1). Fix: list the schema module, or list its table under tables:"
  end

  defp message(%DeclarationIssue{kind: :empty_aggregate} = issue) do
    "aggregate #{hd(issue.aggregates)} declares no schemas and no tables. Fix: add schemas: " <>
      "or tables:, or delete the declaration"
  end

  defp message(%DeclarationIssue{kind: :malformed_attribute} = issue) do
    "@anchor_aggregate on #{subject(issue)} is not [name: atom, schemas: [atom], " <>
      "tables: [binary], owner: boolean]: #{issue.detail}. Fix: write it in this shape"
  end

  defp aggregates(%DeclarationIssue{aggregates: []}), do: "-"
  defp aggregates(%DeclarationIssue{aggregates: names}), do: Enum.join(names, ",")

  defp noun(subject) when is_binary(subject), do: "table"
  defp noun(_module), do: "schema"

  # A table prints quoted, a module by its name, an empty aggregate by its name.
  defp subject(%DeclarationIssue{kind: :empty_aggregate, subject: name}), do: name
  defp subject(%DeclarationIssue{subject: subject}), do: inspect(subject)

  defp and_list(names) do
    {init, [last]} = Enum.split(names, -1)
    Enum.join(init, ", ") <> " and #{last}"
  end
end
