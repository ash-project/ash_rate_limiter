# SPDX-FileCopyrightText: 2025 James Harton
#
# SPDX-License-Identifier: MIT

defmodule AshRateLimiter.BuiltinChanges do
  @moduledoc """
  Change helpers to allow direct usage in mutation actions.
  """
  alias Spark.Options

  @rate_limit_options Options.new!(
                        limit: [
                          type: :pos_integer,
                          required: true,
                          doc: "The maximum number of events allowed within the given scale"
                        ],
                        per: [
                          type: :pos_integer,
                          required: true,
                          doc: "The time period (in milliseconds) for in which events are counted"
                        ],
                        key: [
                          type: {:or, [:string, {:fun, 1}, {:fun, 2}]},
                          required: false,
                          default: &AshRateLimiter.key_for_action/2,
                          doc:
                            "The key used to identify the event. See the docs for `AshRateLimiter.key_for_action/2` for more."
                        ]
                      )

  @type rate_limit_options :: [
          {:limit, pos_integer}
          | {:per, pos_integer}
          | {:key, String.t() | AshRateLimiter.keyfun()}
        ]

  @doc """
  Add a rate-limit change directly to an action.

  ## Options

  #{Options.docs(@rate_limit_options)}

  """
  @spec rate_limit(rate_limit_options) :: {AshRateLimiter.Change, rate_limit_options}
  def rate_limit(options) do
    options = Options.validate!(options, @rate_limit_options)
    {AshRateLimiter.Change, options}
  end
end
