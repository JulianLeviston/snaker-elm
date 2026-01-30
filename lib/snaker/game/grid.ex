defmodule Snaker.Game.Grid do
  @moduledoc "Grid boundaries and position utilities"

  @default_width 30
  @default_height 40

  def default_dimensions, do: {@default_width, @default_height}

  def in_bounds?({x, y}, {width, height}) do
    x >= 0 and x < width and y >= 0 and y < height
  end

  def find_safe_spawn(occupied, dimensions) do
    {width, height} = dimensions
    all_positions = for x <- 0..(width-1), y <- 0..(height-1), do: {x, y}
    available = all_positions -- MapSet.to_list(occupied)

    case available do
      [] -> nil  # Grid full (shouldn't happen in practice)
      positions -> Enum.random(positions)
    end
  end

  def random_position({width, height}) do
    {:rand.uniform(width) - 1, :rand.uniform(height) - 1}
  end
end
