# SPDX-FileCopyrightText: 2025 James Harton
#
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.AshRateLimiter.InstallTest do
  use ExUnit.Case, async: false

  import Igniter.Test

  setup do
    [
      igniter:
        test_project()
        |> Igniter.Project.Application.create_app(Test.Application)
        |> apply_igniter!()
    ]
  end

  test "creates Hammer module with ETS backend", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("ash_rate_limiter.install", ["--setup-hammer"])
    |> assert_creates("lib/test/hammer.ex")
    |> assert_has_patch("lib/test/hammer.ex", """
    1 | defmodule Test.Hammer do
    2 |   use Hammer, backend: :ets
    3 | end
    """)
    |> assert_has_patch("lib/test/application.ex", """
      - | children = []
      + | children = [{Test.Hammer, [clean_period: 60000]}]
    """)
    |> assert_has_patch("config/config.exs", """
    2 | config :test, ash_rate_limiter: [hammer: Test.Hammer]
    """)
  end

  test "installation is idempotent", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("ash_rate_limiter.install", [])
    |> apply_igniter!()
    |> Igniter.compose_task("ash_rate_limiter.install", [])
    |> assert_unchanged()
  end
end
