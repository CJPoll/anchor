ExUnit.start()

# Hammox mock for the config-loading port. `Anchor.Managers.Lint` depends on the
# `Anchor.Adapters.ConfigLoader` behaviour and takes the implementation as an
# injectable option, so tests point the Manager at this mock instead of the real
# filesystem adapter. Using `expect/3` (not `stub/3`) makes the load call
# self-proving — see ADR 002.
Hammox.defmock(Anchor.ConfigLoaderMock, for: Anchor.Adapters.ConfigLoader)
