--[[ Copyright (c) 2026 CorsixTH Modding Pass 2 & Pass 4

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
object.id = "quoiging_chair"
object.thob = 65
object.research_category = "cure"
object.research_fallback = 47
object.name = _S.object.quoiging_chair
object.tooltip = _S.tooltip.objects.quoiging_chair
object.ticks = true
object.mod_machine_sprite = "quoiging_chair"
object.mod_overlay_type = "quoiging_red_hands"
object.build_preview_animation = 5110
object.default_strength = 10
object.crashed_animation = 3396
object.show_in_town_map = true
object.smoke_animation = 3436

local function copy_north_to_south(t)
  t.south = t.north
  return t
end

-- Compact base chair hitbox (rendered beneath custom quoiging_chair_idle/active.png sprites).
object.idle_animations = copy_north_to_south {
  north = 688,
}

object.usage_animations = copy_north_to_south {
  north = {
    in_use = {
      ["Handyman"] = 664,
    },
  },
}

-- Pure patient seating frames without any baked vanilla machine; overlaid by big red tickle gloves,
-- comic HA!/HEE! laughing bursts, and the doctor's spinning silly hat via mod_sprites.lua.
object.multi_usage_animations = {
  ["Standard Male Patient - Doctor"] = copy_north_to_south {
    north = {
      begin_use  = 98,  -- Patient sits into custom Quoiging Chair
      in_use     = 148, -- Patient rocks & laughs while tickled
      finish_use = 218, -- Patient stands up cured
    },
  },
  ["Standard Female Patient - Doctor"] = copy_north_to_south {
    north = {
      begin_use  = 234, -- Patient sits into custom Quoiging Chair
      in_use     = 226, -- Patient rocks & laughs while tickled
      finish_use = 242, -- Patient stands up cured
    },
  },
}

-- Single solid tile {0, 0} keeps origin unshifted so chair, patient, doctor, and overlays align cleanly.
object.orientations = {
  north = {
    footprint = {
      {-1, -1, only_passable = true}, {0, -1, only_passable = true}, {1, -1, only_passable = true},
      {-1, 0, only_passable = true}, {0, 0, complete_cell = true}, {1, 0, only_passable = true},
      {-1, 1, only_passable = true}, {0, 1, only_passable = true}, {1, 1, only_passable = true},
    },
    render_attach_position = {0, 0},
    use_position = {1, 0},
    finish_use_position = {1, 0},
    use_position_secondary = {0, 1},
    handyman_position = {0, -1},
    smoke_position = {0, 0},
  },
  east = {
    footprint = {
      {-1, -1, only_passable = true}, {0, -1, only_passable = true}, {1, -1, only_passable = true},
      {-1, 0, only_passable = true}, {0, 0, complete_cell = true}, {1, 0, only_passable = true},
      {-1, 1, only_passable = true}, {0, 1, only_passable = true}, {1, 1, only_passable = true},
    },
    render_attach_position = {0, 0},
    use_position = {0, 1},
    finish_use_position = {0, 1},
    use_position_secondary = {1, 0},
    handyman_position = {-1, 0},
    smoke_position = {0, 0},
  },
}

local anim_mgr = TheApp.animation_manager
anim_mgr:setPatientMarker(object.idle_animations.north, {0.0, 0.0})
anim_mgr:setStaffMarker(object.usage_animations.north.in_use.Handyman, {60, -4, "px"})

return object
