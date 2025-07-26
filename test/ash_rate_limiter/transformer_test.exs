defmodule AshRateLimiter.TransformerTest do
  use ExUnit.Case, async: true
  alias Example.Post

  describe "transformer behavior" do
    test "rate limited actions are enforced", %{test: test} do
      changeset =
        Post
        |> Ash.Changeset.for_create(:limited_create, %{
          title: "Local Farmer Claims 'Space Zombie' Wrecked His Barn",
          body: """
          Local farmer Otis Peabody is currently under observation by doctors at
          the County Asylum. Mr. Peabody claims he saw a flying saucer and a
          spaceman in his barn. Investigators, after a thorough examination of the
          barn and surroundings, have found no evidence to substantiate Mr.
          Peabody's claims.
          """
        })

      opts = [context: %{key: to_string(test)}]

      {:ok, _} = Ash.create(changeset, opts)
      {:ok, _} = Ash.create(changeset, opts)
      {:ok, _} = Ash.create(changeset, opts)
      {:error, error} = Ash.create(changeset, opts)

      assert %Ash.Error.Forbidden{errors: [error]} = error
      assert %AshRateLimiter.LimitExceeded{} = error
    end

    test "non-rate limited actions work without interference" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{
          title: "Original Title",
          body: "Original Body"
        })
        |> Ash.create!()

      # Update many times quickly - should never be rate limited
      Enum.each(1..10, fn i ->
        updated_post =
          post
          |> Ash.Changeset.for_update(:unlimited_update, %{title: "Updated Title #{i}"})
          |> Ash.update!()

        assert updated_post.title == "Updated Title #{i}"
      end)
    end

    test "changes are added to specific actions only" do
      # Rate limited create action should have a change
      limited_create_action = Ash.Resource.Info.action(Post, :limited_create)
      assert length(limited_create_action.changes) == 1

      change = hd(limited_create_action.changes)
      assert elem(change.change, 0) == AshRateLimiter.Change

      # Non-rate limited update action should have no changes
      unlimited_update_action = Ash.Resource.Info.action(Post, :unlimited_update)
      assert unlimited_update_action.changes == []
    end

    test "preparations are added to specific actions only" do
      # Rate limited read action should have a preparation
      limited_read_action = Ash.Resource.Info.action(Post, :limited_read)
      assert length(limited_read_action.preparations) == 1

      preparation = hd(limited_read_action.preparations)
      assert elem(preparation.preparation, 0) == AshRateLimiter.Preparation

      # Non-rate limited read action should have no preparations
      default_read_action = Ash.Resource.Info.action(Post, :read)
      assert default_read_action.preparations == []
    end
  end
end
