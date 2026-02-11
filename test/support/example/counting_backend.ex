# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: MIT

defmodule Example.CountingBackend do
  @moduledoc false
  @behaviour AshRateLimiter.Backend

  @table __MODULE__

  def start do
    :ets.new(@table, [
      :public,
      :set,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])
  end

  def reset(key) do
    :ets.delete(@table, key)
    :ok
  end

  @impl true
  def hit(key, _window_ms, limit) do
    count = :ets.update_counter(@table, key, {2, 1}, {key, 0})

    if count <= limit do
      {:allow, count}
    else
      {:deny, count}
    end
  end
end
