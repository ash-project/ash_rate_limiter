defmodule Example do
  @moduledoc false
  use Ash.Domain, otp_app: :ash_rate_limiter

  resources do
    resource __MODULE__.Post
  end
end
