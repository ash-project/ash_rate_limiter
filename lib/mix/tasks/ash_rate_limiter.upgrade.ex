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
        Version.parse!("1.0.0") => &upgrade_to_1_0_0/2
      }
    end

    defp upgrade_to_1_0_0(igniter, _opts) do
      igniter
      |> Igniter.Project.Deps.add_dep({:hammer, "~> 7.0"})
      |> rename_hammer_to_backend()
    end

    defp rename_hammer_to_backend(igniter) do
      {igniter, resources} = Ash.Resource.Igniter.list_resources(igniter)

      Enum.reduce(resources, igniter, fn resource, igniter ->
        {igniter, result} = Spark.Igniter.get_option(igniter, resource, [:rate_limit, :hammer])

        case result do
          {:ok, value} ->
            igniter
            |> Spark.Igniter.set_option(resource, [:rate_limit, :backend], value)
            |> remove_hammer_option(resource)

          :error ->
            igniter
        end
      end)
    end

    defp remove_hammer_option(igniter, resource) do
      Igniter.Project.Module.find_and_update_module!(igniter, resource, fn zipper ->
        with {:ok, zipper} <-
               Igniter.Code.Function.move_to_function_call_in_current_scope(
                 zipper,
                 :rate_limit,
                 1
               ),
             {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper) do
          {:ok, remove_hammer_call(zipper)}
        end
      end)
    end

    defp remove_hammer_call(zipper) do
      Igniter.Code.Common.remove(zipper, fn z ->
        Igniter.Code.Function.function_call?(z, :hammer, 1)
      end)
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
