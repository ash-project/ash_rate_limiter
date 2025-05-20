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
    rate limiting features.  See [hammer's documentation](https://hexdocs.pm/hammer) for more information.

    ## Keys

    Hammer uses a "key" to identify which bucket to allocate an event against.  You can use this to tune the rate limit for specific users or events.

    You can provide either a statically configured string key, or a function of arity one or two, which when given a query/changeset and optional context object can generate a key.

    The default is `AshRateLimiter.key_for_action/1`. See it's docs for more information.
    """,
    examples: [
      """
      rate_limit do
        action :create, limit: 10, per: :timer.minutes(5)
      end
      """
    ],
    entities: [
      %Spark.Dsl.Entity{
        name: :action,
        describe: """
        Configure rate limiting for a single action.

        It does this by adding a global change or preparation to the resource with the provided configuration.  For more advanced configuration you can add [the change/preparation/validation](AshRateLimiter.Builtin.rate_limit/1) directly to your action.
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
            doc: "The maximum number of events allowed within the given period"
          ],
          per: [
            type: :pos_integer,
            required: true,
            doc: "The time period (in milliseconds) for in which events are counted"
          ],
          key: [
            type: {:or, [:string, {:fun, 1}, {:fun, 2}]},
            required: false,
            default: &AshRateLimiter.key_for_action/1,
            doc: "The key used to identify the event. See above."
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

  defstruct [:__identifier__, :action, :limit, :per, :key, :description]

  @type t :: %__MODULE__{
          __identifier__: any,
          action: atom,
          limit: pos_integer,
          per: pos_integer | Duration.t(),
          key:
            String.t()
            | (Ash.Query.t() | Ash.Changeset.t() -> String.t())
            | (Ash.Query.t() | Ash.Changeset.t(), Ash.Context.t() -> String.t()),
          description: nil | String.t()
        }

  use Spark.Dsl.Extension, sections: [@rate_limit], transformers: [__MODULE__.Transformer]

  @key_for_action_schema Spark.Options.new!(
                           include_pk?: [
                             type: :boolean,
                             default: true,
                             doc:
                               "Whether or not to include the primary keys in the generated key in update/destroy actions."
                           ],
                           include_actor_attributes: [
                             type: {:wrap_list, :atom},
                             default: [],
                             required: false,
                             doc: "A list of attributes to include from the current actor"
                           ],
                           include_tenant?: [
                             type: :boolean,
                             default: false,
                             doc: "Whether or not to include the tenant in the bucket key."
                           ]
                         )
  @doc """
  The default bucket key generation function for `AshRateLimiter`.

  Generates a key based on the domain, resource and action names. For update and destroy actions it will also include the primary key(s) in the key.

  ## Options

  #{Spark.Options.docs(@key_for_action_schema)}

  ## Examples

      iex> Example.Post
      ...> |> Ash.Changeset.for_create(:create, post_attrs())
      ...> |> key_for_action(%{})
      "example/post/create"

      iex> Example.Post
      ...> |> Ash.Query.for_read(:read)
      ...> |> key_for_action(%{})
      "example/post/read"

      iex> generate_post(id: "0196ebc0-83b4-7938-bc9d-22ae65dbec0b")
      ...> |> Ash.Changeset.for_update(:update, %{title: "Local Farmer Claims 'Space Zombie' Wrecked His Barn"})
      ...> |> key_for_action(%{})
      "example/post/update?id=0196ebc0-83b4-7938-bc9d-22ae65dbec0b"

      iex> generate_post(id: "0196ebc6-4839-7a9e-b2a6-feb0eabc8772")
      ...> |> Ash.Changeset.for_destroy(:destroy)
      ...> |> key_for_action(%{})
      "example/post/destroy?id=0196ebc6-4839-7a9e-b2a6-feb0eabc8772"

      iex> generate_post(id: "0196ebcd-fabf-74c3-9585-8b13c5f07068")
      ...> |> Ash.Changeset.for_destroy(:destroy)
      ...> |> key_for_action(%{}, include_pk?: false)
      "example/post/destroy"

      iex> Example.Post
      ...> |> Ash.Changeset.for_create(:create, post_attrs(), actor: %{role: :time_traveller})
      ...> |> key_for_action(%{}, include_actor_attributes: [:role])
      "example/post/create?actor[role]=time_traveller"

      iex> Example.Post
      ...> |> Ash.Changeset.for_create(:create, post_attrs(), tenant: "Hill Valley Telegraph")
      ...> |> key_for_action(%{}, include_tenant?: true)
      "example/post/create?tenant=Hill%20Valley%20Telegraph"
  """
  def key_for_action(query_or_changeset, context, opts \\ []) do
    opts = Spark.Options.validate!(opts, @key_for_action_schema)
    context = Ash.Context.to_opts(context)

    domain = Ash.Domain.Info.short_name(query_or_changeset.domain)
    resource = Ash.Resource.Info.short_name(query_or_changeset.resource)

    path =
      [domain, resource, query_or_changeset.action.name]
      |> Enum.map(&to_string/1)
      |> Path.join()

    params =
      []
      |> concat_result(fn ->
        if query_or_changeset.action.type in [:update, :destroy] and opts[:include_pk?] do
          query_or_changeset.resource
          |> Ash.Resource.Info.primary_key()
          |> Enum.map(&{to_string(&1), Map.get(query_or_changeset.data, &1)})
        else
          []
        end
      end)
      |> concat_result(fn ->
        context
        |> Keyword.get(:actor, %{})
        |> Map.take(opts[:include_actor_attributes])
        |> Enum.map(fn {k, v} -> {"actor[#{k}]", v} end)
      end)
      |> concat_result(fn ->
        if opts[:include_tenant?] do
          [{"tenant", context[:tenant]}]
        else
          []
        end
      end)
      |> URI.encode_query(:rfc3986)

    if byte_size(params) > 0 do
      "#{path}?#{params}"
    else
      path
    end
  end

  defp concat_result(enum, callback), do: Enum.concat(enum, callback.())
end
