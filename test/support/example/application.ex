# SPDX-FileCopyrightText: 2025 ash_rate_limiter contributors <https://github.com/ash-project/ash_rate_limiter/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Example.Application do
  @moduledoc false

  use Application

  @doc false
  @impl true
  def start(_type, _args) do
    [{Example.Hammer, clean_period: :timer.minutes(1)}]
    |> Supervisor.start_link(strategy: :one_for_one, name: __MODULE__)
  end
end
