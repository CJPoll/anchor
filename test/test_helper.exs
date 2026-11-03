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
