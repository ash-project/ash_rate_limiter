# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

**Testing:**
- `mix test` - Run all tests
- `mix test test/path/to/specific_test.exs` - Run a specific test file
- `mix test test/path/to/specific_test.exs:42` - Run a specific test line

**Development:**
- `mix deps.get` - Install dependencies
- `mix compile` - Compile the project
- `mix docs` - Generate documentation (includes Spark cheat sheets)
- `mix credo --strict` - Run linting with strict mode
- `mix dialyzer` - Run type checking
- `mix format` - Format code
- `mix spark.formatter` - Format Spark DSL code with AshRateLimiter extensions

**Documentation:**
- `mix spark.cheat_sheets` - Generate Spark DSL cheat sheets

## Architecture Overview

This is an Elixir library that provides rate limiting functionality for the Ash framework. It's built as a Spark DSL extension that integrates with the Hammer rate limiting library.

**Core Components:**

- **DSL Extension** (`lib/ash_rate_limiter.ex`): Defines the `rate_limit` DSL section that can be added to Ash resources
- **Transformer** (`lib/ash_rate_limiter/transformer.ex`): Spark transformer that processes DSL configuration and automatically adds changes/preparations to actions
- **Change** (`lib/ash_rate_limiter/change.ex`): Ash change for create/update/destroy actions
- **Preparation** (`lib/ash_rate_limiter/preparation.ex`): Ash preparation for read actions
- **Key Generation**: Default key generation function `key_for_action/2` creates unique bucket keys based on domain, resource, action, and optionally primary keys, actor attributes, and tenant

**Integration Pattern:**
The library works by automatically injecting rate limiting logic into Ash actions through the transformer. When you configure `rate_limit` in a resource, it:
1. Validates the action exists and is supported (create/read/update/destroy only)
2. Adds a global change (for CUD actions) or preparation (for read actions) to the resource
3. The change/preparation uses Hammer to enforce rate limits before the action executes

**Rate Limiting Strategy:**
Uses Hammer's bucket-based rate limiting with configurable:
- `limit`: Maximum events allowed
- `per`: Time window in milliseconds  
- `key`: Function or string to generate bucket keys (defaults to `key_for_action/2`)

**Example Setup:**
Example domain and resources are in `test/support/` for testing the library functionality.