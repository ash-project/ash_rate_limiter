defmodule Example.Post do
  @moduledoc false
  use Ash.Resource, data_layer: Ash.DataLayer.Ets, domain: Example, extensions: [AshRateLimiter]

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :limited_create, accept: :*
    read :limited_read
  end

  rate_limit do
    hammer Example.Hammer
    action :limited_create, limit: 3, per: :timer.seconds(3), key: &key_fun/2
    action :limited_read, limit: 3, per: :timer.seconds(3), key: &key_fun/2
  end

  attributes do
    uuid_v7_primary_key :id, writable?: true
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :body, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  ets do
    table :posts
    private? true
  end

  defp key_fun(_, context), do: context.key
end
