# SPDX-FileCopyrightText: 2025 James Harton
#
# SPDX-License-Identifier: MIT

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshRateLimiter.Install do
    @moduledoc """
    Installs AshRateLimiter into your application.

    Should be run with `mix igniter.install ash_rate_limiter`

    ## Options

    * `--setup-hammer` - Generates a Hammer backend module and adds it to your
      application supervision tree (default: false)
    """
    @shortdoc "Installs AshRateLimiter"

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _source) do
      %Igniter.Mix.Task.Info{
        adds_deps: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter =
        igniter
        |> Igniter.Project.Formatter.import_dep(:ash_rate_limiter)
        |> Spark.Igniter.prepend_to_section_order(:"Ash.Resource", [:rate_limit])

      setup_hammer_backend(igniter)
    end

    defp setup_hammer_backend(igniter) do
      otp_app = Igniter.Project.Application.app_name(igniter)
      hammer_module = Igniter.Project.Module.module_name(igniter, "Hammer")

      igniter
      |> create_hammer_module(hammer_module)
      |> add_to_supervision_tree(hammer_module)
      |> configure_hammer(otp_app, hammer_module)
    end

    defp create_hammer_module(igniter, module_name) do
      Igniter.Project.Module.create_module(
        igniter,
        module_name,
        """
        use Hammer, backend: :ets
        """,
        []
      )
    end

    defp add_to_supervision_tree(igniter, module_name) do
      Igniter.Project.Application.add_new_child(
        igniter,
        {module_name, clean_period: :timer.minutes(1)}
      )
    end

    defp configure_hammer(igniter, otp_app, hammer_module) do
      Igniter.Project.Config.configure(
        igniter,
        "config.exs",
        otp_app,
        [:ash_rate_limiter, :hammer],
        hammer_module
      )
    end
  end
else
  defmodule Mix.Tasks.AshRateLimiter.Install do
    @moduledoc """
    Installs AshRateLimiter. Requires igniter to be installed.

    Should be run with `mix igniter.install ash_rate_limiter`
    """
    @shortdoc "Installs AshRateLimiter"

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_rate_limiter.install' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
