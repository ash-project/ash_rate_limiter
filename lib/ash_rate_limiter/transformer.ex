# SPDX-FileCopyrightText: 2025 ash_rate_limiter contributors <https://github.com/ash-project/ash_rate_limiter/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshRateLimiter.Transformer do
  @moduledoc """
  A Spark DSL transformer for rate limiting.
  """
  use Spark.Dsl.Transformer
  import Spark.Dsl.Transformer
  alias Ash.Resource.{Dsl, Info}
  alias AshRateLimiter.{Change, Preparation}
  alias Spark.Error.DslError

  @doc false
  @impl true
  def after?(_), do: true

  @doc false
  @impl true
  def transform(dsl) do
    dsl
    |> get_entities([:rate_limit])
    |> Enum.reduce_while({:ok, dsl}, fn entity, {:ok, dsl} ->
      case transform_entity(entity, dsl) do
        {:ok, dsl} -> {:cont, {:ok, dsl}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp transform_entity(entity, dsl) do
    with {:ok, action} <- validate_action(entity, dsl) do
      add_change_or_preparation(entity, action, dsl)
    end
  end

  defp validate_action(entity, dsl) do
    case Info.action(dsl, entity.action) do
      nil ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:rate_limit, :action, entity.action, :action],
           message: """
           Action #{entity.action} not found.
           """
         )}

      action when action.type in [:create, :read, :update, :destroy, :action] ->
        {:ok, action}
    end
  end

  defp add_change_or_preparation(entity, action, dsl) when action.type in [:read, :action],
    do: add_preparation_to_action(entity, action, dsl)

  defp add_change_or_preparation(entity, action, dsl),
    do: add_change_to_action(entity, action, dsl)

  defp add_preparation_to_action(entity, action, dsl) do
    with {:ok, preparation} <-
           build_entity(Dsl, [:preparations], :prepare,
             preparation:
               {Preparation, limit: entity.limit, per: entity.per, key: entity.key, on: entity.on}
           ) do
      updated_action = %{action | preparations: [preparation | action.preparations]}
      {:ok, replace_entity(dsl, [:actions], updated_action, &(&1.name == action.name))}
    end
  end

  defp add_change_to_action(entity, action, dsl) do
    with {:ok, change} <-
           build_entity(Dsl, [:changes], :change,
             change:
               {Change, limit: entity.limit, per: entity.per, key: entity.key, on: entity.on}
           ) do
      updated_action = %{action | changes: [change | action.changes]}
      {:ok, replace_entity(dsl, [:actions], updated_action, &(&1.name == action.name))}
    end
  end
end
