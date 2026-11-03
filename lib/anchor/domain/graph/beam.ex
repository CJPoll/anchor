defmodule Anchor.Domain.Graph.Beam do
  @moduledoc """
  One decoded project beam — **Domain** data (ADR 001), plain values only
  (DND-5438).

  `Anchor.Adapters.BeamReader` builds it from a `.beam` binary without loading
  the module; `Anchor.Domain.Graph.Builder` turns a list of them into the graph.

    * `:module`, `:app`, `:path` — the module, the OTP app whose ebin held it,
      and the beam's path.
    * `:elixir` — the `elixir_v1` debug-info metadata map (`:definitions`,
      `:attributes` (persisted only), `:struct`, `:relative_file`, ...).
    * `:core` — the module as Core Erlang (a `:cerl` `c_module`), from the
      backend's `debug_info(:core_v1, ...)`, the way Dialyzer reads it.
    * `:specs`, `:types` — `Code.Typespec.fetch_specs/1` and `fetch_types/1` of
      the binary, in Erlang abstract format (`[]` when the module has none).

  A beam that cannot be decoded is a `t:decode_error/0`, never a `%Beam{}`
  with empty fields.
  """

  @enforce_keys [:module, :app, :path]
  defstruct [:module, :app, :path, :elixir, :core, specs: [], types: []]

  @type t :: %__MODULE__{
          module: module(),
          app: atom(),
          path: String.t(),
          elixir: map() | nil,
          core: :cerl.cerl() | nil,
          specs: [{{atom(), arity()}, [tuple()]}],
          types: [{:type | :typep | :opaque, tuple()}]
        }

  @typedoc """
  Why a beam could not be decoded:

    * `:no_debug_info` — the beam has no debug-info chunk.
    * `:debug_info_stripped` — the chunk is there but holds no metadata
      (`debug_info: false`), or is encrypted.
    * `{:not_elixir, backend}` — another language's backend wrote it (an Erlang
      module's is `:erl_abstract_code`).
    * `{:elixir_v1_refused, reason}` / `{:core_v1_refused, reason}` — the
      backend returned an error for that format; `{:core_v1_refused,
      {:transform, {kind, module}}}` when the module was compiled with a
      `parse_transform` or `core_transform`, which lowering would run, and
      `{:core_v1_refused, {:option, option}}` for any other compile option not
      on the reader's allowlist of options known to run no code (DND-5552).
    * `{:unreadable, reason}` — the file (or ebin directory) could not be read,
      or the bytes are not a beam.
    * `{:decode_crashed, message}` — decoding raised, threw or exited.
  """
  @type reason ::
          :no_debug_info
          | :debug_info_stripped
          | {:not_elixir, module()}
          | {:elixir_v1_refused, term()}
          | {:core_v1_refused, term()}
          | {:unreadable, term()}
          | {:decode_crashed, String.t()}

  @type decode_error ::
          {:error, %{path: String.t(), module: module() | nil, reason: reason()}}
end
