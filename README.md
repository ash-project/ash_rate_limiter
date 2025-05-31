![Logo](https://github.com/ash-project/ash/blob/main/logos/cropped-for-header-black-text.png?raw=true#gh-light-mode-only)
![Logo](https://github.com/ash-project/ash/blob/main/logos/cropped-for-header-white-text.png?raw=true#gh-dark-mode-only)

[![Ash CI](https://github.com/ash-project/ash_rate_limiter/actions/workflows/elixir.yml/badge.svg)](https://github.com/ash-project/ash_rate_limiter/actions/workflows/elixir.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_rate_limiter.svg)](https://hex.pm/packages/ash_rate_limiter)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/ash_rate_limiter)

# AshRateLimiter

Welcome! This is an extension for the [Ash framework](https://hexdocs.pm/ash)
which protects [actions](https://hexdocs.pm/ash/actions.html) from abuse by enforcing rate limits.

Uses the excellent [hammer](https://hex.pm/packages/hammer) to provide rate limiting functionality.

## Installation

Add `ash_rate_limiter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_rate_limiter, "~> 0.1.1"}
  ]
end
```

## Quick Start

1. **Configure Hammer**: First, you need to configure a Hammer backend. For development, you can use the ETS backend:

```elixir
# config/config.exs
config :hammer,
  backend: {Hammer.Backend.ETS, []}
```

For production, consider using Redis:

```elixir
# config/config.exs  
config :hammer,
  backend: {Hammer.Backend.Redis, [
    host: "localhost",
    port: 6379
  ]}
```

2. **Add to your resource**: Use the `rate_limit` DSL section in your Ash resource:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    domain: MyApp,
    extensions: [AshRateLimiter]

  rate_limit do
    # Configure hammer backend
    hammer Hammer
    
    # Limit create action to 10 requests per 5 minutes
    action :create, limit: 10, per: :timer.minutes(5)
    
    # Limit read action to 100 requests per minute  
    action :read, limit: 100, per: :timer.minutes(1)
  end

  # ... rest of your resource definition
end
```

3. **That's it!** Your actions are now rate limited. When the limit is exceeded, an `AshRateLimiter.LimitExceeded` error will be raised.

## Basic Usage

### Simple Rate Limiting

```elixir
rate_limit do
  hammer Hammer
  action :create, limit: 5, per: :timer.minutes(1)
end
```

### Per-User Rate Limiting

```elixir
rate_limit do
  hammer Hammer
  action :create, 
    limit: 10, 
    per: :timer.minutes(5),
    key: fn changeset, context ->
      "user:#{context.actor.id}:create"
    end
end
```

### Multiple Actions

```elixir
rate_limit do
  hammer Hammer
  action :create, limit: 10, per: :timer.minutes(5)
  action :update, limit: 20, per: :timer.minutes(5) 
  action :read, limit: 100, per: :timer.minutes(1)
end
```

## Advanced Usage

### Manual Integration

For more control, you can add rate limiting directly to specific actions:

```elixir
defmodule MyApp.Post do
  use Ash.Resource, domain: MyApp

  actions do
    create :create do
      change {AshRateLimiter.Change, limit: 10, per: :timer.minutes(5)}
    end
    
    read :read do
      prepare {AshRateLimiter.Preparation, limit: 100, per: :timer.minutes(1)}
    end
  end
end
```

Or use the built-in helpers:

```elixir
actions do
  create :create do
    change rate_limit(limit: 10, per: :timer.minutes(5))
  end
end
```

### Custom Key Functions

The key function determines how requests are grouped for rate limiting:

```elixir
# Rate limit per IP address
key: fn _changeset, context ->
  "ip:#{context[:ip_address]}"
end

# Rate limit per user and action
key: fn changeset, context ->
  "user:#{context.actor.id}:action:#{changeset.action.name}"
end

# Use the built-in key function with options
key: {&AshRateLimiter.key_for_action/2, include_actor_attributes: [:role]}
```

## Error Handling

When rate limits are exceeded, an `AshRateLimiter.LimitExceeded` exception is raised:

```elixir
case MyApp.create_post(attrs) do
  {:ok, post} -> 
    # Success
    {:ok, post}
    
  {:error, %AshRateLimiter.LimitExceeded{} = error} ->
    # Rate limit exceeded
    {:error, "Too many requests, please try again later"}
    
  {:error, other_error} ->
    # Handle other errors
    {:error, other_error}
end
```

In web applications, the exception includes `Plug.Exception` behaviour for automatic HTTP 429 responses.

## Testing

In test environments, you may want to disable rate limiting or use a test-friendly configuration:

```elixir
# config/test.exs
config :hammer,
  backend: {Hammer.Backend.ETS, []}

# Or disable rate limiting entirely in tests by using a mock
```

## Reference

- [AshRateLimiter DSL](documentation/dsls/DSL-AshRateLimiter.md)
- [Hammer Documentation](https://hexdocs.pm/hammer)
