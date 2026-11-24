--[[ Copyright (c) 2026 CorsixTH Modding Pass 3 & Pass 4

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. --]]

local object = {}
object.id = "up_down_rig"
object.thob = 66
object.research_category = "cure"
object.research_fallback = 48
object.name = _S.object.up_down_rig
object.tooltip = _S.tooltip.objects.up_down_rig
object.ticks = true
object.mod_machine_sprite = "up_down_rig"
object.mod_overlay_type = "up_down_big_hands"
object.build_preview_animation = 928
object.default_strength = 9
object.crashed_animation = 3312
object.show_in_town_map = true
object.smoke_animation = 3440

local function copy_north_to_south(t)
  t.south = t.north
  return t
end

-- Compact base hitbox completely covered by custom up_down_rig_idle/active.png gantry sprites.
object.idle_animations = copy_north_to_south {
  north = 688,
}

object.walk_in_to_use = true -- This is only considered by use_object, not multi_use_object.
object.usage_animations = copy_north_to_south {
  north = {
    in_use = { ["Handyman"] = 3502 },
  },
}

-- Standalone Doctor animation (no vanilla jelly tank baked in) while Doctor operates
-- the gantry console and the custom rig grabs the patient by the leg and turns them upside down.
object.multi_usage_animations = {
  ["Doctor - Standard Male Patient"] = copy_north_to_south {
    north = {
      begin_use  = 40, -- Doctor steps up to gantry console
      in_use     = 40, -- Doctor operates winch while rig grabs ankle & flips patient
      finish_use = 40, -- Doctor lowers winch cleanly
    },
  },
  ["Doctor - Standard Female Patient"] = copy_north_to_south {
    north = {
      begin_use  = 40,
      in_use     = 40,
      finish_use = 40,
    },
  },
}

-- Single solid console tile {0, 0} keeps origin unshifted so gantry pulley aligns 1:1 with patient pad.
object.orientations = {
  north = {
    footprint = {
      {0, -1, only_passable = true}, {1, -1, only_passable = true},
      {0, 0, complete_cell = true}, {1, 0, only_passable = true},
      {0, 1, only_passable = true}, {1, 1, only_passable = true},
    },
    render_attach_position = {0, 0},
    use_animate_from_use_position = true,
    use_position = {0, 1},
    finish_use_position = {0, 1},
    use_position_secondary = {1, 0},
    finish_use_position_secondary = {1, 0},
    finish_use_orientation_secondary = "east",
    handyman_position = {0, -1},
    smoke_position = {0, 0},
  },
  east = {
    footprint = {
      {-1, 0, only_passable = true}, {0, 0, complete_cell = true}, {1, 0, only_passable = true},
      {-1, 1, only_passable = true}, {0, 1, only_passable = true}, {1, 1, only_passable = true},
    },
    render_attach_position = {0, 0},
    use_animate_from_use_position = true,
    use_position = {1, 0},
    finish_use_position = {1, 0},
    use_position_secondary = {0, 1},
    finish_use_position_secondary = {0, 1},
    finish_use_orientation_secondary = "south",
    handyman_position = {-1, 0},
    smoke_position = {0, 0},
  },
}

return object
