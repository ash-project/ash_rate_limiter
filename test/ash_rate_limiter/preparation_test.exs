defmodule AshRateLimiter.PreparationTest do
  use ExUnit.Case, async: true
  alias AshRateLimiter.Preparation
  alias Example.Post

  describe "init/1" do
    test "it validates the options correctly" do
      assert {:error, _} = Preparation.init(wat: :lame)
      assert {:ok, opts} = Preparation.init(action: :read, limit: 3, per: 4)
      assert opts[:action] == :read
      assert opts[:limit] == 3
      assert opts[:per] == 4
      assert opts[:key] == (&AshRateLimiter.key_for_action/2)
    end
  end

  describe "prepare/3" do
    test "calling at a rate lower than specified is fine", %{test: test} do
      query = Post |> Ash.Query.for_read(:limited_read)
      opts = [context: %{key: to_string(test)}]

      {:ok, _} = Ash.read(query, opts)
      {:ok, _} = Ash.read(query, opts)
      {:ok, _} = Ash.read(query, opts)
    end

    test "calling at a rate higher than returns an error", %{test: test} do
      query = Post |> Ash.Query.for_read(:limited_read)
      opts = [context: %{key: to_string(test)}]

      {:ok, _} = Ash.read(query, opts)
      {:ok, _} = Ash.read(query, opts)
      {:ok, _} = Ash.read(query, opts)
      {:error, error} = Ash.read(query, opts)

      assert %Ash.Error.Forbidden{errors: [error]} = error
      assert %AshRateLimiter.LimitExceeded{} = error
    end
  end
end
