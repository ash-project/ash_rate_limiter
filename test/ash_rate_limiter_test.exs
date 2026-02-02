# SPDX-FileCopyrightText: 2025 ash_rate_limiter contributors <https://github.com/ash-project/ash_rate_limiter/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshRateLimiterTest do
  use ExUnit.Case
  import AshRateLimiter
  doctest AshRateLimiter

  def post_attrs(attrs \\ []) do
    attrs
    |> Map.new()
    |> Map.put_new(:title, "Local Farmer Claims 'Space Zombie' Wrecked His Barn")
    |> Map.put_new(:body, """
    Local farmer Otis Peabody is currently under observation by doctors at
    the County Asylum. Mr. Peabody claims he saw a flying saucer and a
    spaceman in his barn. Investigators, after a thorough examination of the
    barn and surroundings, have found no evidence to substantiate Mr.
    Peabody's claims.
    """)
  end

  def generate_post(attrs \\ []) do
    params = post_attrs(attrs)

    Example.Post
    |> Ash.create!(params, authorize?: false)
  end
end
