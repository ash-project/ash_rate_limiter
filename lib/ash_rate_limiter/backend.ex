# SPDX-FileCopyrightText: 2025 ash_rate_limiter contributors <https://github.com/ash-project/ash_rate_limiter/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshRateLimiter.Backend do
  @moduledoc """
  A behaviour for rate limiting backends.

  Implement this behaviour to provide a custom rate limiting backend for use with `AshRateLimiter`.

  ## Example

      defmodule MyApp.RateLimiter do
        @behaviour AshRateLimiter.Backend

        @impl true
        def hit(key, window_ms, limit) do
          # Your rate limiting logic here
          {:allow, 1}
        end
      end
  """

  @callback hit(key :: String.t(), window_ms :: pos_integer(), limit :: pos_integer()) ::
              {:allow, pos_integer()} | {:deny, pos_integer()}
end
