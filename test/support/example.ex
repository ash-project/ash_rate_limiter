# SPDX-FileCopyrightText: 2025 ash_rate_limiter contributors <https://github.com/ash-project/ash_rate_limiter/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Example do
  @moduledoc false
  use Ash.Domain, otp_app: :ash_rate_limiter

  resources do
    resource __MODULE__.Post
  end
end
