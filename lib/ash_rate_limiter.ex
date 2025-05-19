defmodule AshRateLimiter do
  @moduledoc """
  An extension for `Ash.Resource` which adds the ability to rate limit access to actions.
  """

  @rate_limit %Spark.Dsl.Section{
    name: :rate_limit,
    describe: """
    Configure rate limiting for actions.

    ## Hammer

    This library uses the [hammer](https://hex.pm/packages/hammer) package to provide
    rate limiting features.  Therefore we use hammer's terminology for options. See
    [hammer's documentation](https://hexdocs.pm/hammer) for more information.
    """,
    examples: [
      """
      rate_limit do
        limit :create, limit: 10, scale: :timer.minutes(5) hammer: MyApp.Hammer
      end
      """
    ],
    entities: [
      %Spark.Dsl.Entity{
        name: :limit,
        describe: """
        Configure rate limiting for a single action.
        """,
        target: __MODULE__,
        identifier: :action,
        schema: [
          action: [
            type: :atom,
            required: true,
            doc: "The name of the action to limit"
          ],
          limit: [
            type: :pos_integer,
            required: true,
            doc: "The maximum number of events allowed within the given scale"
          ],
          scale: [
            type: :pos_integer,
            required: true,
            doc: "The time period (in milliseconds) for in which events are counted"
          ],
          key: [
            type: :string,
            required: false,
            doc: "The unique key used to identify the action. Auto-generated if not set."
          ],
          description: [
            type: :string,
            required: false,
            doc: "A description of the rate limit"
          ]
        ]
      }
    ],
    schema: [
      hammer: [
        type: {:behaviour, Hammer},
        required: true,
        doc: "The hammer module to use for rate limiting"
      ]
    ]
  }

  defstruct [:__identifier__, :action, :limit, :scale, :key, :description]

  @type t :: %__MODULE__{
          __identifier__: any,
          action: atom,
          limit: pos_integer,
          scale: pos_integer | Duration.t(),
          key: nil | String.t(),
          description: nil | String.t()
        }

  use Spark.Dsl.Extension, sections: [@rate_limit], transformers: [__MODULE__.Transformer]
end
