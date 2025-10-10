# SPDX-FileCopyrightText: 2025 James Harton
#
# SPDX-License-Identifier: MIT

defmodule AshRateLimiter.ChangeTest do
  use ExUnit.Case, async: true
  alias AshRateLimiter.Change
  alias Example.Post

  describe "init/1" do
    test "it validates the options correctly" do
      assert {:error, _} = Change.init(wat: :lame)
      assert {:ok, opts} = Change.init(action: :create, limit: 3, per: 4)
      assert opts[:action] == :create
      assert opts[:limit] == 3
      assert opts[:per] == 4
      assert opts[:key] == (&AshRateLimiter.key_for_action/2)
    end
  end

  describe "change/3" do
    test "calling at a rate lower than specified is fine", %{test: test} do
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
    end

    test "calling at a rate higher than returns an error", %{test: test} do
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
  end
end
