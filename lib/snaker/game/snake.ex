defmodule Snaker.Game.Snake do
  @moduledoc "Snake movement, growth, and collision detection"

  alias Snaker.Game.Grid

  @directions %{
    up: {0, -1},
    down: {0, 1},
    left: {-1, 0},
    right: {1, 0}
  }

  @opposites %{up: :down, down: :up, left: :right, right: :left}

  def new(id, position, color, name) do
    %{
      id: id,
      segments: [position],  # Head-first list
      direction: :right,
      color: color,
      name: name,
      pending_growth: 0,
      invincible_until: System.monotonic_time(:millisecond) + 1500
    }
  end

  def move(snake, grid_dimensions) do
    {dx, dy} = @directions[snake.direction]
    [{hx, hy} | _] = snake.segments
    new_head = {hx + dx, hy + dy}

    # Handle wall wrap-around (or collision - depending on game rules)
    # For now, wrap around
    {width, height} = grid_dimensions
    new_head = {rem(elem(new_head, 0) + width, width), rem(elem(new_head, 1) + height, height)}

    new_segments =
      if snake.pending_growth > 0 do
        [new_head | snake.segments]
      else
        [new_head | Enum.drop(snake.segments, -1)]
      end

    %{snake |
      segments: new_segments,
      pending_growth: max(0, snake.pending_growth - 1)
    }
  end

  def grow(snake, amount \\ 1) do
    %{snake | pending_growth: snake.pending_growth + amount}
  end

  def change_direction(snake, new_direction) when is_atom(new_direction) do
    if valid_direction_change?(snake.direction, new_direction) do
      {:ok, %{snake | direction: new_direction}}
    else
      {:error, :invalid_direction}
    end
  end

  def valid_direction_change?(current, new) do
    @opposites[current] != new
  end

  def head(%{segments: [head | _]}), do: head

  def body(%{segments: [_ | body]}), do: body

  def all_positions(%{segments: segments}), do: segments

  def collides_with_self?(%{segments: [head | body]}) do
    head in body
  end

  def collides_with?(snake, other_snake) when snake.id != other_snake.id do
    head(snake) in all_positions(other_snake)
  end
  def collides_with?(_, _), do: false

  def is_invincible?(snake) do
    System.monotonic_time(:millisecond) < snake.invincible_until
  end
end
