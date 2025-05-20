defmodule AshRateLimiter.LimitExceeded do
  use Splode.Error, fields: [:hammer, :limit, :per, :key], class: :forbidden

  def message(_) do
    "Rate limit exceeded"
  end
end
