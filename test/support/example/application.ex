# SPDX-FileCopyrightText: 2025 James Harton
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
