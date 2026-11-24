--[[ Copyright (c) 2026 CorsixTH Modding Pass 4

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

local TH = require("TH")

--! Stateless helper for Pass 4 custom machines, overlays, and patient inversion.
-- All mutable state on entities/machines is stored as plain serializable primitives
-- or TH.spriteList userdata; never attach closures to entities or rooms.
local ModSprites = {}

ModSprites.SHEET_NAME = "mod_sprites"

ModSprites.FRAME_FILES = {
  "quoiging_chair_idle.png",
  "quoiging_chair_active.png",
  "quoiging_red_hands_01.png",
  "quoiging_red_hands_02.png",
  "quoiging_red_hands_03.png",
  "quoiging_red_hands_04.png",
  "quoiging_silly_hat_01.png",
  "quoiging_silly_hat_02.png",
  "quoiging_silly_hat_03.png",
  "quoiging_silly_hat_04.png",
  "up_down_rig_idle.png",
  "up_down_rig_active.png",
  "up_down_leg_grab_01.png",
  "up_down_leg_grab_02.png",
  "up_down_dangle_male_01.png",
  "up_down_dangle_male_02.png",
  "up_down_dangle_male_03.png",
  "up_down_dangle_male_04.png",
  "up_down_dangle_female_01.png",
  "up_down_dangle_female_02.png",
  "up_down_dangle_female_03.png",
  "up_down_dangle_female_04.png",
  "up_down_claw_hold_01.png",
  "up_down_claw_hold_02.png",
}

ModSprites.QUOIGING_CHAIR_IDLE = 0
ModSprites.QUOIGING_CHAIR_ACTIVE = 1
ModSprites.QUOIGING_FRAMES = { 2, 3, 4, 5 }
ModSprites.SILLY_HAT_FRAMES = { 6, 7, 8, 9 }

ModSprites.UP_DOWN_RIG_IDLE = 10
ModSprites.UP_DOWN_RIG_ACTIVE = 11
ModSprites.UP_DOWN_LEG_GRAB_FRAMES = { 12, 13 }
ModSprites.UP_DOWN_DANGLE_MALE_FRAMES = { 14, 15, 16, 17 }
ModSprites.UP_DOWN_DANGLE_FEMALE_FRAMES = { 18, 19, 20, 21 }
ModSprites.UP_DOWN_CLAW_HOLD_FRAMES = { 22, 23 }

ModSprites.MACHINE_SPRITES = {
  quoiging_chair = {
    idle_idx = ModSprites.QUOIGING_CHAIR_IDLE,
    active_idx = ModSprites.QUOIGING_CHAIR_ACTIVE,
    width = 112,
    offset = { -56, -78 },
  },
  up_down_rig = {
    idle_idx = ModSprites.UP_DOWN_RIG_IDLE,
    active_idx = ModSprites.UP_DOWN_RIG_ACTIVE,
    width = 160,
    offset = { -64, -96 },
  },
}

ModSprites.QUOIGING_OFFSETS = {
  north = { -48, -82 },
  east = { -48, -82 },
  south = { -48, -82 },
  west = { -48, -82 },
}

ModSprites.SILLY_HAT_OFFSET = { -24, -84 }

ModSprites.UP_DOWN_OFFSETS = {
  north = { -48, -96 },
  east = { -48, -96 },
  south = { -48, -96 },
  west = { -48, -96 },
}

--! Returns true when the running binary exposes native PNG loading
-- (compiled together with C++ THAnimation vertical-flip rendering).
function ModSprites.hasNativePngAndFlip()
  local gfx = TheApp and TheApp.gfx
  if gfx and gfx.has_native_mod_pngs ~= nil then
    return gfx.has_native_mod_pngs
  end
  local sheet_ctor = TH and TH.sheet
  if not sheet_ctor then
    return false
  end
  local ok, sample = pcall(sheet_ctor)
  local has_png = ok and sample ~= nil and type(sample.loadPNGs) == "function"
  if gfx then
    gfx.has_native_mod_pngs = has_png
  end
  return has_png
end

function ModSprites.getSheet()
  local gfx = TheApp and TheApp.gfx
  if gfx and gfx.loadModSprites then
    return gfx:loadModSprites(ModSprites.SHEET_NAME)
  end
  return nil
end

function ModSprites.detachOverlay(overlay)
  if overlay and overlay.setTile then
    overlay:setTile(nil)
  end
end

function ModSprites.attachOverlay(world, tx, ty, sprite_idx, offset_x, offset_y, layer, flip_h)
  if not world or not world.map or not world.map.th or not tx or not ty then
    return nil
  end
  local sheet = ModSprites.getSheet()
  if not sheet or not TH or not TH.spriteList then
    return nil
  end
  local srl = TH.spriteList()
  srl:setSheet(sheet)
  srl:append(sprite_idx, 0, 0)
  srl:setPosition(offset_x or 0, offset_y or 0)
  local flags = (DrawFlags and DrawFlags.Nearest) or 0
  if flip_h then
    flags = flag_set(flags, DrawFlags.FlipHorizontal)
  end
  if srl.setFlag and flags ~= 0 then
    srl:setFlag(flags)
  end
  local default_layer = (DrawingLayers and DrawingLayers.MachineSmoke) or 6
  srl:setTile(world.map.th, tx, ty, layer or default_layer)
  return srl
end

function ModSprites.setPatientInverted(patient, inverted, lift_y, offset_x)
  if not patient then
    return
  end
  if not inverted then
    ModSprites.clearPatientInverted(patient)
    return
  end

  local flip_flag = DrawFlags.FlipVertical
  patient.up_down_inverted = true
  patient.permanent_flags = flag_set(patient.permanent_flags or 0, flip_flag)
  if patient.th and patient.th.setPartialFlag then
    patient.th:setPartialFlag(flip_flag, true)
  end
  if patient.animation_flags then
    patient.animation_flags = flag_set(patient.animation_flags, flip_flag)
  end

  local invis_flags = (DrawFlags.Alpha50 or 0) + (DrawFlags.Alpha75 or 0)

  if ModSprites.hasNativePngAndFlip() then
    if patient.up_down_hidden_for_dangle then
      patient.up_down_hidden_for_dangle = nil
      if patient.permanent_flags and invis_flags ~= 0 then
        local cleared = flag_clear(patient.permanent_flags, invis_flags)
        patient.permanent_flags = (cleared ~= 0) and cleared or nil
      end
      if patient.th and patient.th.makeVisible then
        patient.th:makeVisible()
      end
    end
    if patient.setPosition and patient.th then
      patient:setPosition(offset_x or 0, lift_y or -74)
    end
  else
    patient.up_down_hidden_for_dangle = true
    if invis_flags ~= 0 then
      patient.permanent_flags = flag_set(patient.permanent_flags or 0, invis_flags)
    end
    if patient.th and patient.th.makeInvisible then
      patient.th:makeInvisible()
    end
  end
end

function ModSprites.clearPatientInverted(patient)
  if not patient then
    return
  end
  local flip_flag = DrawFlags.FlipVertical
  local invis_flags = (DrawFlags.Alpha50 or 0) + (DrawFlags.Alpha75 or 0)
  local was_hidden = patient.up_down_hidden_for_dangle
  if patient.permanent_flags then
    local cleared = flag_clear(patient.permanent_flags, flip_flag)
    if was_hidden and invis_flags ~= 0 then
      cleared = flag_clear(cleared, invis_flags)
    end
    patient.permanent_flags = (cleared ~= 0) and cleared or nil
  end
  if patient.animation_flags then
    patient.animation_flags = flag_clear(patient.animation_flags, flip_flag)
    if was_hidden and invis_flags ~= 0 then
      patient.animation_flags = flag_clear(patient.animation_flags, invis_flags)
    end
  end
  if patient.th then
    if patient.th.setPartialFlag then
      patient.th:setPartialFlag(flip_flag, false)
    end
    if was_hidden and patient.th.makeVisible then
      patient.th:makeVisible()
    end
  end
  if patient.setPosition and patient.th then
    patient:setPosition(0, 0)
  end
  patient.up_down_hidden_for_dangle = nil
  patient.up_down_inverted = nil
end

function ModSprites.clearMachineBaseSprite(machine)
  if not machine then
    return
  end
  if machine.mod_machine_sprite then
    ModSprites.detachOverlay(machine.mod_machine_sprite)
    machine.mod_machine_sprite = nil
  end
  machine.mod_machine_sprite_key = nil
end

function ModSprites.syncMachineBaseSprite(machine, is_active)
  local sprite_key = machine and machine.object_type and machine.object_type.mod_machine_sprite
  if not sprite_key then
    return
  end
  local spec = ModSprites.MACHINE_SPRITES[sprite_key]
  if not spec or machine.mod_machine_crashed or not machine.tile_x or not machine.tile_y then
    ModSprites.clearMachineBaseSprite(machine)
    return
  end

  local dir = machine.direction or "north"
  local flip_h = (dir == "east" or dir == "west")
  local off_x = spec.offset[1]
  if flip_h then
    off_x = -(spec.width + off_x)
  end
  local off_y = spec.offset[2]
  local sprite_idx = is_active and spec.active_idx or spec.idle_idx
  local key = sprite_idx .. ":" .. machine.tile_x .. ":" .. machine.tile_y .. ":" .. (flip_h and 1 or 0)
  if machine.mod_machine_sprite and machine.mod_machine_sprite_key == key then
    return
  end

  ModSprites.detachOverlay(machine.mod_machine_sprite)
  local base_layer = (DrawingLayers and DrawingLayers.AtomAnalyser) or 3
  machine.mod_machine_sprite = ModSprites.attachOverlay(
    machine.world, machine.tile_x, machine.tile_y, sprite_idx, off_x, off_y, base_layer, flip_h
  )
  machine.mod_machine_sprite_key = machine.mod_machine_sprite and key or nil
end

function ModSprites.clearStaffOverlay(machine)
  if not machine then
    return
  end
  if machine.mod_staff_overlay then
    ModSprites.detachOverlay(machine.mod_staff_overlay)
    machine.mod_staff_overlay = nil
  end
  machine.mod_staff_overlay_key = nil
end

local function restoreQuoigingUserPosition(machine, user)
  if not user or not user.setPosition or not user.th then
    return
  end
  local dir = machine and machine.direction or "north"
  local orient = machine and machine.object_type and machine.object_type.orientations and
      machine.object_type.orientations[dir]
  local anim_off = orient and orient.animation_offset
  local base_px = anim_off and anim_off[1] or 0
  local base_py = anim_off and anim_off[2] or 0
  user:setPosition(base_px, base_py)
end

function ModSprites.clearMachineOverlay(machine)
  if not machine then
    return
  end
  if machine.mod_overlay then
    ModSprites.detachOverlay(machine.mod_overlay)
    machine.mod_overlay = nil
  end
  ModSprites.clearStaffOverlay(machine)

  local overlay_type = machine.object_type and machine.object_type.mod_overlay_type
  if machine.mod_overlay_patient then
    if overlay_type == "up_down_big_hands" then
      ModSprites.clearPatientInverted(machine.mod_overlay_patient)
    else
      restoreQuoigingUserPosition(machine, machine.mod_overlay_patient)
    end
    machine.mod_overlay_patient = nil
  end
  machine.mod_overlay_tick = nil
  machine.mod_overlay_frame = nil
  machine.mod_overlay_phase = nil
  machine.mod_overlay_phase_tick = nil

  if machine.object_type and machine.object_type.mod_machine_sprite then
    ModSprites.syncMachineBaseSprite(machine, false)
  end
end

local function swapMachineOverlay(machine, tx, ty, sprite_idx, off_x, off_y, key, flip_h)
  if machine.mod_overlay and machine.mod_overlay_frame == key then
    return
  end
  ModSprites.detachOverlay(machine.mod_overlay)
  local layer = (DrawingLayers and DrawingLayers.MachineSmoke) or 6
  machine.mod_overlay = ModSprites.attachOverlay(
    machine.world, tx, ty, sprite_idx, off_x, off_y, layer, flip_h
  )
  machine.mod_overlay_frame = machine.mod_overlay and key or nil
end

local function syncDoctorSillyHat(machine, staff, frame_pos)
  if not staff or not staff.tile_x or not staff.tile_y then
    ModSprites.clearStaffOverlay(machine)
    return
  end
  local sprite_idx = ModSprites.SILLY_HAT_FRAMES[frame_pos]
  local hat_off = ModSprites.SILLY_HAT_OFFSET
  local bob_y = (frame_pos % 2 == 0) and -2 or 0
  local hat_key = sprite_idx .. ":" .. staff.tile_x .. ":" .. staff.tile_y .. ":" .. bob_y
  if machine.mod_staff_overlay and machine.mod_staff_overlay_key == hat_key then
    return
  end
  ModSprites.detachOverlay(machine.mod_staff_overlay)
  local layer = (DrawingLayers and DrawingLayers.FloatingDollars) or 7
  machine.mod_staff_overlay = ModSprites.attachOverlay(
    machine.world, staff.tile_x, staff.tile_y, sprite_idx, hat_off[1], hat_off[2] + bob_y, layer, false
  )
  machine.mod_staff_overlay_key = machine.mod_staff_overlay and hat_key or nil
end

local function tickQuoigingOverlay(machine, user, action, phase)
  if not phase or phase < -5 or phase > 1 then
    ModSprites.clearMachineOverlay(machine)
    return
  end

  ModSprites.syncMachineBaseSprite(machine, phase == 0)
  machine.mod_overlay_tick = (machine.mod_overlay_tick or 0) + 1
  local frame_pos = (math.floor((machine.mod_overlay_tick - 1) / 3) % #ModSprites.QUOIGING_FRAMES) + 1

  -- Doctor wears the spinning jester-propeller silly hat throughout treatment
  syncDoctorSillyHat(machine, action.use_with, frame_pos)

  -- Red hands, tickle feathers, and laughing HA!/HEE! bursts activate once patient is seated (phase == 0)
  if phase ~= 0 then
    if machine.mod_overlay then
      ModSprites.detachOverlay(machine.mod_overlay)
      machine.mod_overlay = nil
      machine.mod_overlay_frame = nil
    end
    if machine.mod_overlay_patient then
      restoreQuoigingUserPosition(machine, machine.mod_overlay_patient)
      machine.mod_overlay_patient = nil
    end
    return
  end

  local sprite_idx = ModSprites.QUOIGING_FRAMES[frame_pos]
  local dir = machine.direction or "north"
  local base_off = ModSprites.QUOIGING_OFFSETS[dir] or ModSprites.QUOIGING_OFFSETS.north
  local wiggle_x = (frame_pos % 2 == 0) and -3 or 3
  local wiggle_y = (frame_pos == 2 or frame_pos == 4) and -2 or 1

  -- Lively belly-laugh bounce & rock on seated patient
  local orient = machine.object_type.orientations and machine.object_type.orientations[dir]
  local anim_off = orient and orient.animation_offset
  local base_px = anim_off and anim_off[1] or 0
  local base_py = anim_off and anim_off[2] or 0
  if user.setPosition and user.th then
    local laugh_dx = (frame_pos % 2 == 0) and 2 or -2
    local laugh_dy = (frame_pos == 1 or frame_pos == 3) and -3 or 0
    user:setPosition(base_px + laugh_dx, base_py + laugh_dy)
    machine.mod_overlay_patient = user
  end

  local tx, ty = machine:getRenderAttachTile()
  tx = tx or machine.tile_x
  ty = ty or machine.tile_y
  local flip_h = (dir == "east" or dir == "west")
  local cache_key = phase * 16 + frame_pos
  swapMachineOverlay(machine, tx, ty, sprite_idx, base_off[1] + wiggle_x, base_off[2] + wiggle_y, cache_key, flip_h)
end

local function tickUpDownOverlay(machine, action, phase)
  local patient = action.use_with
  if not patient or not phase or phase < -5 or phase > 1 then
    ModSprites.clearMachineOverlay(machine)
    return
  end

  ModSprites.syncMachineBaseSprite(machine, true)
  if machine.mod_overlay_patient and machine.mod_overlay_patient ~= patient then
    ModSprites.clearPatientInverted(machine.mod_overlay_patient)
  end
  machine.mod_overlay_patient = patient

  if machine.mod_overlay_phase ~= phase then
    machine.mod_overlay_phase = phase
    machine.mod_overlay_phase_tick = 1
  else
    machine.mod_overlay_phase_tick = (machine.mod_overlay_phase_tick or 0) + 1
  end
  local pt = machine.mod_overlay_phase_tick

  local dir = machine.direction or "north"
  local base_off = ModSprites.UP_DOWN_OFFSETS[dir] or ModSprites.UP_DOWN_OFFSETS.north
  local sprite_idx, off_x, off_y, step_key

  if phase < 0 then
    -- Stage 1 (begin_use): Doctor operates console, winch cable drops toward patient's ankle
    if action.setInvisiblePhaseSpan then
      action:setInvisiblePhaseSpan({99, 100})
    elseif action.invisible_phase_span then
      action.invisible_phase_span = {99, 100}
    end
    if patient.up_down_inverted then
      ModSprites.clearPatientInverted(patient)
    end
    sprite_idx = ModSprites.UP_DOWN_LEG_GRAB_FRAMES[1]
    off_x = base_off[1]
    off_y = base_off[2]
    step_key = phase * 100 + 1
  elseif phase == 0 then
    -- Stage 2 (ticks 1..14): Grab by the leg! (cable lowers -> ankle clamp snap)
    if pt <= 14 then
      if action.setInvisiblePhaseSpan then
        action:setInvisiblePhaseSpan({99, 100})
      elseif action.invisible_phase_span then
        action.invisible_phase_span = {99, 100}
      end
      if patient.up_down_inverted then
        ModSprites.clearPatientInverted(patient)
      end
      local grab_step = (pt <= 7) and 1 or 2
      sprite_idx = ModSprites.UP_DOWN_LEG_GRAB_FRAMES[grab_step]
      if grab_step == 2 and patient.setPosition and patient.th then
        patient:setPosition(0, -3)
      elseif patient.setPosition and patient.th then
        patient:setPosition(0, 0)
      end
      off_x = base_off[1]
      off_y = base_off[2]
      step_key = 1000 + grab_step
    elseif pt <= 46 then
      -- Stage 3 (ticks 15..46): Yanked & turned upside down by the leg, swinging cleanly!
      local flip_t = pt - 14
      if ModSprites.hasNativePngAndFlip() then
        if action.setInvisiblePhaseSpan then
          action:setInvisiblePhaseSpan({99, 100})
        elseif action.invisible_phase_span then
          action.invisible_phase_span = {99, 100}
        end
        local cycle = math.floor((flip_t - 1) / 4) % 2
        local sway_x = (cycle == 0) and -2 or 2
        local bob_y = (cycle == 0) and -2 or 2
        ModSprites.setPatientInverted(patient, true, -74 + bob_y, sway_x)
        sprite_idx = ModSprites.UP_DOWN_CLAW_HOLD_FRAMES[cycle + 1]
        off_x = base_off[1] + sway_x
        off_y = base_off[2]
        step_key = 2000 + cycle
      else
        -- Keep MultiUseObjectAction aligned so it never calls makeVisible() over the dangle sprite!
        if action.setInvisiblePhaseSpan then
          action:setInvisiblePhaseSpan({0, 0})
        else
          action.invisible_phase_span = {0, 0}
        end
        ModSprites.setPatientInverted(patient, true, 0, 0)
        local is_female = patient.humanoid_class and patient.humanoid_class:find("Female", 1, true) ~= nil
        local seq = is_female and ModSprites.UP_DOWN_DANGLE_FEMALE_FRAMES or ModSprites.UP_DOWN_DANGLE_MALE_FRAMES
        local frame_pos
        if flip_t <= 6 then
          frame_pos = 1 -- mid-flip yank
        else
          local swing_seq = { 2, 3, 2, 4 }
          frame_pos = swing_seq[(math.floor((flip_t - 7) / 4) % 4) + 1]
        end
        sprite_idx = seq[frame_pos]
        off_x = base_off[1]
        off_y = base_off[2]
        step_key = 3000 + (is_female and 10 or 0) + frame_pos
      end
    else
      -- Stage 4 (ticks 47+): Set back down upright and release ankle
      if action.setInvisiblePhaseSpan then
        action:setInvisiblePhaseSpan({99, 100})
      elseif action.invisible_phase_span then
        action.invisible_phase_span = {99, 100}
      end
      ModSprites.clearPatientInverted(patient)
      sprite_idx = ModSprites.UP_DOWN_LEG_GRAB_FRAMES[1]
      off_x = base_off[1]
      off_y = base_off[2]
      step_key = 4000 + 1
    end
  else
    -- finish_use (phase == 1): upright & unclasped
    if action.setInvisiblePhaseSpan then
      action:setInvisiblePhaseSpan({99, 100})
    elseif action.invisible_phase_span then
      action.invisible_phase_span = {99, 100}
    end
    ModSprites.clearPatientInverted(patient)
    sprite_idx = ModSprites.UP_DOWN_LEG_GRAB_FRAMES[1]
    off_x = base_off[1]
    off_y = base_off[2]
    step_key = 5000 + 1
  end

  local tx = patient.tile_x
  local ty = patient.tile_y
  if not tx or not ty then
    tx, ty = machine:getRenderAttachTile()
    tx = tx or machine.tile_x
    ty = ty or machine.tile_y
  end
  local flip_h = (dir == "east" or dir == "west")
  swapMachineOverlay(machine, tx, ty, sprite_idx, off_x, off_y, step_key, flip_h)
end

function ModSprites.tickMachineOverlay(machine)
  if not machine or not machine.object_type then
    return
  end

  if machine.object_type.mod_machine_sprite then
    ModSprites.syncMachineBaseSprite(machine, machine.user ~= false and machine.user ~= nil)
  end

  if not machine.object_type.mod_overlay_type then
    return
  end

  local user = machine.user
  local action = user and user.getCurrentAction and user:getCurrentAction() or nil
  if not action or action.name ~= "multi_use_object" or action.object ~= machine then
    ModSprites.clearMachineOverlay(machine)
    return
  end

  local overlay_type = machine.object_type.mod_overlay_type
  if overlay_type == "quoiging_red_hands" then
    tickQuoigingOverlay(machine, user, action, action.phase)
  elseif overlay_type == "up_down_big_hands" then
    tickUpDownOverlay(machine, action, action.phase)
  end
end

return ModSprites
