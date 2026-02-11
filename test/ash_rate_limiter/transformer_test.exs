# SPDX-FileCopyrightText: 2025 ash_rate_limiter contributors <https://github.com/ash-project/ash_rate_limiter/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshRateLimiter.TransformerTest do
  use ExUnit.Case, async: true
  alias Ash.Error.Forbidden
  alias Ash.Resource.Info
  alias AshRateLimiter.Change
  alias AshRateLimiter.LimitExceeded
  alias AshRateLimiter.Preparation
  alias Example.Post

  setup %{test: test} do
    Example.CountingBackend.reset(to_string(test))
    :ok
  end

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

      assert %Forbidden{errors: [error]} = error
      assert %LimitExceeded{} = error
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
      limited_create_action = Info.action(Post, :limited_create)
      assert length(limited_create_action.changes) == 1

      change = hd(limited_create_action.changes)
      assert elem(change.change, 0) == Change

      # Non-rate limited update action should have no changes
      unlimited_update_action = Info.action(Post, :unlimited_update)
      assert unlimited_update_action.changes == []
    end

    test "preparations are added to specific actions only" do
      # Rate limited read action should have a preparation
      limited_read_action = Info.action(Post, :limited_read)
      assert length(limited_read_action.preparations) == 1

      preparation = hd(limited_read_action.preparations)
      assert elem(preparation.preparation, 0) == Preparation

      # Non-rate limited read action should have no preparations
      default_read_action = Info.action(Post, :read)
      assert default_read_action.preparations == []
    end

    test "preparations are added to generic actions" do
      # Rate limited generic action should have a preparation
      limited_action = Info.action(Post, :limited_action)
      assert length(limited_action.preparations) == 1

      preparation = hd(limited_action.preparations)
      assert elem(preparation.preparation, 0) == Preparation
    end

    test "rate limited generic actions are enforced", %{test: test} do
      input =
        Post
        |> Ash.ActionInput.for_action(:limited_action, %{message: "hello"})
        |> Ash.ActionInput.set_context(%{key: to_string(test)})

      {:ok, _} = Ash.run_action(input)
      {:ok, _} = Ash.run_action(input)
      {:ok, _} = Ash.run_action(input)
      {:error, error} = Ash.run_action(input)

      assert %Forbidden{errors: [error]} = error
      assert %LimitExceeded{} = error
    end
  end
end
