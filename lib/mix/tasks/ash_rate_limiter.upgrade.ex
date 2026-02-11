# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshRateLimiter.Upgrade do
    @moduledoc """
    Handles upgrade steps for AshRateLimiter between versions.

    This task is called automatically by `mix igniter.upgrade ash_rate_limiter`.
    """
    @shortdoc "Upgrades AshRateLimiter"

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _source) do
      %Igniter.Mix.Task.Info{
        positional: [:from, :to]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      from = Version.parse!(igniter.args.positional.from)
      to = Version.parse!(igniter.args.positional.to)
      opts = igniter.args.options

      Igniter.Upgrades.run(igniter, from, to, upgrades(), opts)
    end

    defp upgrades do
      %{
        Version.parse!("1.0.0") => &add_hammer_dep/2
      }
    end

    defp add_hammer_dep(igniter, _opts) do
      Igniter.Project.Deps.add_dep(igniter, {:hammer, "~> 7.0"})
    end
  end
else
  defmodule Mix.Tasks.AshRateLimiter.Upgrade do
    @moduledoc """
    Upgrades AshRateLimiter. Requires igniter to be installed.

    Should be run with `mix igniter.upgrade ash_rate_limiter`
    """
    @shortdoc "Upgrades AshRateLimiter"

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_rate_limiter.upgrade' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
