ExUnit.start()

# Hammox mock for the config-loading port. `Anchor.Managers.Lint` depends on the
# `Anchor.Adapters.ConfigLoader` behaviour and takes the implementation as an
# injectable option, so tests point the Manager at this mock instead of the real
# filesystem adapter. Using `expect/3` (not `stub/3`) makes the load call
# self-proving — see ADR 002.
Hammox.defmock(Anchor.ConfigLoaderMock, for: Anchor.Adapters.ConfigLoader)

# Hammox mock for the change-source port (DND-5472): `Anchor.Managers.Sabotage`
# and `mix anchor.sabotage` take it through the `:change_source` option.
Hammox.defmock(Anchor.ChangeSourceMock, for: Anchor.Adapters.ChangeSource)

# Hammox mocks for the graph runner's ports (DND-5440): `Anchor.Managers.Graph`
# and `mix anchor.graph` take them through the `:beam_source`, `:source_source`
# and `:graph_store` options.
#
# BeamSource is a plain Mox mock (Hammox's own base, same expect/verify API):
# its return type holds `:cerl.cerl()`, an Erlang record type Hammox's type
# engine cannot match, so a Hammox mock fails every call. Its tests call
# `Mox.expect/4` on it, which self-verifies the same way.
Mox.defmock(Anchor.BeamSourceMock, for: Anchor.Adapters.BeamSource)
Hammox.defmock(Anchor.SourceSourceMock, for: Anchor.Adapters.SourceSource)
Hammox.defmock(Anchor.GraphStoreMock, for: Anchor.Adapters.GraphStore)

# DND-5473: the sabotage runner's ports (`Anchor.Managers.Sabotage.run/2`
# takes them as the `:source_mutation`, `:git_worktree` and `:test_execution`
# options).
Hammox.defmock(Anchor.SourceMutationMock, for: Anchor.Adapters.SourceMutation)
Hammox.defmock(Anchor.GitWorktreeMock, for: Anchor.Adapters.GitWorktree)
Hammox.defmock(Anchor.TestExecutionMock, for: Anchor.Adapters.TestExecution)

# DND-5441: the baseline ports (`Anchor.Managers.Graph.run/2` takes them as the
# `:baseline_store` and `:git_base` options).
Hammox.defmock(Anchor.BaselineStoreMock, for: Anchor.Adapters.BaselineStore)
Hammox.defmock(Anchor.GitBaseMock, for: Anchor.Adapters.GitBase)
