pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- init code

-- map tileset:
-- https://thkaspar.itch.io/micro-tileset-overworld-dungeon

-- consts
sprite_size = 8

-- globals
character = nil
companion = nil
show_path = true
path_long = nil
path_short = nil

-- init functions
function init_character(idx, x, y, speed)
  return {
    sprite = idx,
    animation = {idx + 1, idx + 2},
    tick = 0,
    frame = 1,
    step = 6 / speed,
    speed = speed,

    x = x * sprite_size,
    y = y * sprite_size,
    flip = false
  }
end

function is_map_blocked(x, y)
  if (x < 0 or x > 16 or y < 0 or y > 16) return true
  return fget(mget(x, y), 0)
end

function check_collisions(x, y)
  local x1 = x / sprite_size
  local y1 = y / sprite_size
  local x2 = (x + sprite_size - 1) / sprite_size
  local y2 = (y + sprite_size - 1) / sprite_size

  return is_map_blocked(x1, y1) or is_map_blocked(x1, y2) or is_map_blocked(x2, y1) or is_map_blocked(x2, y2)
end

function move(obj, input)
  local x = obj.x
  local y = obj.y

  if (input.left) then
    if (not check_collisions(obj.x - obj.speed, obj.y)) then obj.x -= obj.speed obj.flip = true end
  elseif (input.right) then
    if (not check_collisions(obj.x + obj.speed, obj.y)) then obj.x += obj.speed obj.flip = false end
  end

  if (input.up) then
    if (not check_collisions(obj.x, obj.y - obj.speed)) then obj.y -= obj.speed end
  elseif (input.down) then
    if (not check_collisions(obj.x, obj.y + obj.speed)) then obj.y += obj.speed end
  end

  if (obj.x == x and obj.y == y) then
    obj.moving = false
    obj.tick = 0
  else
    obj.moving = true
  end
end

function chase(obj, target)
  path_long = nil
  path_short = nil
  local input = find_long_path(obj, target)
  move(obj, input)
end

function animate(obj)
  obj.tick = (obj.tick + 1) % obj.step
  if (obj.tick == 0) obj.frame = (obj.frame % #obj.animation) + 1
  if (obj.tick == 0 and obj.frame == 1) then obj.block_actions = false end
end

function player_input()
  return {
    left = btn(0),
    right = btn(1),
    up = btn(2),
    down = btn(3),
    o = btn(4),
    x = btn(5)
  }
end

function draw(obj)
  if (obj.moving) then
    spr(obj.animation[obj.frame], obj.x, obj.y, 1, 1, obj.flip)
  else
    spr(obj.sprite, obj.x, obj.y, 1, 1, obj.flip)
  end
end

function draw_path()
  if (path_long and #path_long > 1) then
    del(path_long, path_long[1])
    del(path_long, path_long[#path_long])
    foreach(path_long, function(coords)
      x = sprite_size * coords.x
      y = sprite_size * coords.y
      rect(x, y, x + sprite_size, y + sprite_size, 10)
    end)
  end
  if (path_short and #path_short > 1) then
    foreach(path_short, function(coords) pset(coords.x + sprite_size / 2, coords.y + sprite_size / 2, 7) end)
  end
end

function _init()
  poke(0x5f2d, 1)

  character = init_character(16, 15, 15, 2)
  companion = init_character(32, 0, 0, 1)
  companion.step = 8

  character.speed = 2
end

function _update()
  if btnp(5) then show_path = not show_path end

  move(character, player_input())
  chase(companion, character)
  foreach({ character, companion }, animate)
end

function _draw()
  cls(12)
  map(0, 0, 0, 0, 16, 16)
  foreach({ character, companion }, draw)
  if (show_path) then draw_path() end
end


-->8
-- grid/pixel pathfinding
function to_grid_coords(x, y)
  return {
    x = flr(x / sprite_size),
    y = flr(y / sprite_size)
  }
end

function check_map_collisions(x, y)
  local x1 = x / sprite_size
  local y1 = y / sprite_size
  local x2 = (x + sprite_size - 1) / sprite_size
  local y2 = (y + sprite_size - 1) / sprite_size

  return is_map_blocked(x1, y1) or is_map_blocked(x1, y2) or is_map_blocked(x2, y1) or is_map_blocked(x2, y2)
end

function get_neighbors(node, blocked)
  local neighbors = {}
  if (not blocked.up) add(neighbors, { x = node.x, y = node.y - 1})
  if (not blocked.down) add(neighbors, { x = node.x, y = node.y + 1})
  if (not blocked.left) add(neighbors, { x = node.x - 1, y = node.y})
  if (not blocked.right) add(neighbors, { x = node.x + 1, y = node.y})
  if (not blocked.up_left) add(neighbors, { x = node.x - 1, y = node.y - 1})
  if (not blocked.up_right) add(neighbors, { x = node.x + 1, y = node.y - 1})
  if (not blocked.down_left) add(neighbors, { x = node.x - 1, y = node.y + 1})
  if (not blocked.down_right) add(neighbors, { x = node.x + 1, y = node.y + 1})
  return neighbors
end

function map_neighbors_pixel(pixel)
  local grid_coords = to_grid_coords(pixel.x, pixel.y)
  local grid_x = grid_coords.x * sprite_size
  local grid_y = grid_coords.y * sprite_size

  local blocked = {}
  if (pixel.x == grid_x) then
    blocked.left = check_map_collisions(pixel.x - 1, pixel.y)
    blocked.right = check_map_collisions(pixel.x + 1, pixel.y)
  end
  if (pixel.y == grid_y) then
    blocked.up = check_map_collisions(pixel.x, pixel.y - 1)
    blocked.down = check_map_collisions(pixel.x, pixel.y + 1)
  end

  if (check_map_collisions(pixel.x - 1, pixel.y - 1)) blocked.up_left = true
  if (check_map_collisions(pixel.x + 1, pixel.y - 1)) blocked.up_right = true
  if (check_map_collisions(pixel.x - 1, pixel.y + 1)) blocked.down_left = true
  if (check_map_collisions(pixel.x + 1, pixel.y + 1)) blocked.down_right = true

  return get_neighbors(pixel, blocked)
end

function map_neighbors_grid(node)
  local blocked = {
    up = is_map_blocked(node.x, node.y - 1),
    down = is_map_blocked(node.x, node.y + 1),
    left = is_map_blocked(node.x - 1, node.y),
    right = is_map_blocked(node.x + 1, node.y)
  }
  if ((blocked.up and blocked.left) or is_map_blocked(node.x - 1, node.y - 1)) blocked.up_left = true
  if ((blocked.up and blocked.right) or is_map_blocked(node.x + 1, node.y - 1)) blocked.up_right = true
  if ((blocked.down and blocked.left) or is_map_blocked(node.x - 1, node.y + 1)) blocked.down_left = true
  if ((blocked.down and blocked.right) or is_map_blocked(node.x + 1, node.y + 1)) blocked.down_right = true

  return get_neighbors(node, blocked)
end

function find_short_path(source, target)
  local path = find_path(source, target, manhattan_distance, map_neighbors_pixel)
  path_short = path
  return path[#path - 1]
end

function find_long_path(source, target)
  local c1 = to_grid_coords(source.x, source.y)
  local c2 = to_grid_coords(target.x, target.y)

  local path = find_path(c1, c2, manhattan_distance, map_neighbors_grid)
  if not path or #path < 2 then return {} end
  path_long = path

  local next_grid = path[#path - 1]
  local next_coords = { x = next_grid.x * sprite_size, y = next_grid.y * sprite_size}
  local next = find_short_path(source, next_coords)
  if (not next) then return {} end

  local direction = {}
  if (next.x > source.x) then direction.right = true
  elseif (next.x < source.x) then direction.left = true
  end
  if (next.y > source.y) then direction.down = true
  elseif (next.y < source.y) then direction.up = true
  end

  return direction
end

-->8
-- pathfinding algorithm from https://github.com/morgan3d/misc/blob/master/p8pathfinder/pathfinder.p8
function manhattan_distance(a, b)
  return abs(a.x - b.x) + abs(a.y - b.y)
end

function node_to_id(node)
  return shl(node.y, 8) + node.x
end

function find_path(start, goal, estimate, neighbors)
  local shortest = {
    last = start,
    cost_from_start = 0,
    cost_to_goal = estimate(start, goal)
  }
  local best_table = {}

  best_table[node_to_id(start)] = shortest
  local frontier = { shortest }
  local frontier_len = 1
  local goal_id = node_to_id(goal)
  local max_number = 32767.99

  while frontier_len > 0 do
    local cost, index_of_min = max_number
    for i = 1, frontier_len do
      local temp = frontier[i].cost_from_start + frontier[i].cost_to_goal
      if (temp <= cost) index_of_min, cost = i, temp
    end

    shortest = frontier[index_of_min]
    frontier[index_of_min] = frontier[frontier_len]
    shortest.dead = true
    frontier_len -= 1

    local p = shortest.last

    if node_to_id(p) == goal_id then
      p = { goal }
      while shortest.prev do
        shortest = best_table[node_to_id(shortest.prev)]
        add(p, shortest.last)
      end
      return p
    end

    for n in all(neighbors(p)) do
      local id = node_to_id(n)
      local old_best = best_table[id]
      local new_cost_from_start = shortest.cost_from_start + 1

      if not old_best then
        old_best = {
          last = n,
          cost_from_start = max_number,
          cost_to_goal = estimate(n, goal)
        }
        frontier_len += 1
        frontier[frontier_len] = old_best
        best_table[id] = old_best
      end

      if not old_best.dead and old_best.cost_from_start > new_cost_from_start then
        old_best.cost_from_start = new_cost_from_start
        old_best.prev = p
      end
    end
  end
end


__gfx__
00000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000bbbbbbbbbbbbbbbbbbbbbbbb0000000000000000bb3333bbbb3333bb
00000000bbbbbbbbbbbbbbbbbbbbbbbbbbb33b3b3b33bb3b3b33bbbbbbbbbbbb00000000bbb33b3b3b33bb3b3b33bbbb0000000000000000b3bbbb3bb3bbbb3b
00000000bbbbbb3bbbbbbbbbbbbbbbbbbbb003030300330303003bbbbbbbbbbb00000000bbb223232322332323223bbb00000000000000003bbbbbb33bbbbbb3
00000000bbbbb33bbbbbbbbbbb3bbbbbbb30000000000000000003bbbbbbbbbb00000000bb32442224424222244223bb00000000000000003bbbbbb33bbbbbb3
0000000033bbb3bbbbbbbbbbbb33bbbbb3000000000000000000003bbbbbbbbb00000000b3224424244222422442423b00000000000000003b33bb333b33bb33
00000000b33bbbbbbbbbb33bbbb3bbbbb000000000000000000000bbbbbbbbbb00000000b242222222222222222222bb0000000000000000b333333bb33333bb
00000000bbbbbbbbbbbb33bbbbbbbbbbbb000000000000000000003bbbbbbbbb00000000bb22dddddddddddddddd243b0000000000000000bb3223bbbb323bbb
00000000bbbbbbbbbbbbbbbbbbbbbbbbb3000000000000000000000bbbbbbbbb00000000b32d0000000000000000d22b000000dddd000000bbb22bbbbbb23b3b
00000000000000000000000000000000bb00000000000000000000bb0000000330000000bbd000000000000000000dbb00000d2332d0000000000000bb333333
00011100000011100000111000000000b0000000000000000000000b0000000000000000b3d000000000000000000d3b00000d2222d0000000000000b3bbbb33
0001ff0000001ff000001ff000000000bb000000000000000000000b0000000000000000bbd000000000000000000d2b00000d2222d00000000000003bbbbbb3
00011000000011000000110000000000bb00000000000000000000bb0000000000000000bbd000000000000000000dbb00000d2222d00000000000003bbbbbb3
0011110000f1110000f1110000000000b000000000000000000000bb0000000000000000b3d000000000000000000dbb000000d22d000000000000003b33bb33
001f11f0000111000001110000000000b0000000000000000000000b0000000000000000b2d000000000000000000d3b0000000dd000000000000000b33333bb
00011100000110000001100000000000bb00000000000000000000bb0000000000000000bbd000000000000000000dbb000000000000000000000000bb323bbb
000f0f0000f00f000000f00000000000b0000000000000000000000b0000000000000000b3d000000000000000000d3b000000000000000000000000bbb23b3b
00000000000000000000000000000000bb00000000000000000000bb0000000000000000bbd000000000000000000dbb32d0000000000d2300000000bb333333
000ddd000000ddd00000ddd000000000b0000000000000000000000b0000000000000000b3d000000000000000000d3b22d0000000000d2200000000b3bbbb33
000dff000000dff00000dff000000000bb000000000000000000000b0000000000000000bbd000000000000000000d2b22d0000000000d22000000003bbbbbb3
000dd0000000dd000000dd0000000000bb00000000000000000000bb0000000000000000bbd000000000000000000dbb22d0000000000d22000000003bbbbbb3
00dddd0000fddd0000fddd0000000000b000000000000000000000bb0000000000000000b3d000000000000000000dbb2d000000000000d2000000003b33bb33
00dfddf0000ddd00000ddd0000000000bbb000000000000000000bbb0000000000000000bbb000000000000000000bbbd00000000000000d00000000b333333b
000ddd00000dd000000dd00000000000bbbb00b0b0bb00b0b0bb0bbb0000000000000000bbbb00b0b0bb00b0b0bb0bbb000000000000000000000000bb3223bb
000f0f0000f00f000000f00000000000bbbbbbbbbbbbbbbbbbbbbbbb0000000000000000bbbbbbbbbbbbbbbbbbbbbbbb000000dddd00000000000000bbb22bbb
__gff__
0000000001010100000101010000010100000000010101000001010101010001000000000101010000010101010100010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0707070707070207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07070e07090a0a0a0a0a0b070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070e0707242a2a2a2a0d1b070e07070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070707070707070707191b070e070e0700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020307040505050607191b030e070e0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070301141525252607191b070e020f0700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070e07141607070707191b0701070e0700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070e03141607070707191b0e07070e0700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070707141607040607191b070e0e070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020707141505181607191b070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070702242525252607191b070107070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
030707070707070707191b070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07070701090a0a0a0a1d1b070f0e070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070f0e07191a1a1a0c2a2b070e0e070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070e0e07292525252b070707020e030700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0707070707070707070703070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
