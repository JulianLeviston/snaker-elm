defmodule Snaker.Game.Apple do
  @moduledoc "Apple spawning and management"

  alias Snaker.Game.Grid

  @min_apples 3
  @growth_per_apple 3

  def spawn_if_needed(apples, occupied_positions, grid_dimensions) do
    if length(apples) < @min_apples do
      all_occupied = MapSet.union(occupied_positions, MapSet.new(apples))
      case Grid.find_safe_spawn(all_occupied, grid_dimensions) do
        nil -> apples
        position -> [position | apples]
      end
    else
      apples
    end
  end

  def check_eaten(apples, snake_head) do
    if snake_head in apples do
      {true, apples -- [snake_head]}
    else
      {false, apples}
    end
  end

  def growth_amount, do: @growth_per_apple
end
