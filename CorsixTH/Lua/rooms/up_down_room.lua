--[[ Copyright (c) 2026 CorsixTH Modding Pass 3

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

local ModSprites = require("mod_sprites")

local room = {}
room.id = "up_down_room"
room.vip_must_visit = false
room.level_config_id = 32
room.class = "UpDownRoom"
room.name = _S.rooms_short.up_down_room
room.long_name = _S.rooms_long.up_down_room
room.tooltip = _S.tooltip.rooms.up_down_room
room.objects_additional = { "extinguisher", "radiator", "plant", "bin" }
room.objects_needed = { up_down_rig = 1 }
-- Base preview icon paired with Pass 4 giant-hands overlay & patient inversion on up_down_rig.
room.build_preview_animation = 928
room.categories = {
  clinics = 10,
}
room.minimum_size = 4
room.wall_type = "blue"
room.floor_tile = 17
room.required_staff = {
  Doctor = 1,
}
room.maximum_staff = room.required_staff
room.call_sound = "reqd020.wav"
room.handyman_call_sound = "maint009.wav"

class "UpDownRoom" (Room)

---@type UpDownRoom
local UpDownRoom = _G["UpDownRoom"]

function UpDownRoom:UpDownRoom(...)
  self:Room(...)
end

function UpDownRoom:restorePatientOrientation(patient)
  if patient then
    ModSprites.clearPatientInverted(patient)
    if self.inverted_patient == patient then
      self.inverted_patient = nil
    end
  end
end

function UpDownRoom:cleanupTreatmentVisuals(patient)
  self:restorePatientOrientation(patient)
  if self.inverted_patient then
    self:restorePatientOrientation(self.inverted_patient)
  end
  if not self.objects then
    return
  end
  for object, _ in pairs(self.objects) do
    if object.object_type and object.object_type.id == "up_down_rig" then
      ModSprites.clearMachineOverlay(object)
    end
  end
end

function UpDownRoom:onHumanoidEnter(humanoid)
  return Room.onHumanoidEnter(self, humanoid)
end

function UpDownRoom:onHumanoidLeave(humanoid)
  if humanoid == self.inverted_patient or humanoid == self.staff_member then
    self:cleanupTreatmentVisuals(humanoid)
  elseif class.is(humanoid, Patient) then
    self:restorePatientOrientation(humanoid)
  end
  return Room.onHumanoidLeave(self, humanoid)
end

function UpDownRoom:makeHumanoidLeave(humanoid)
  if class.is(humanoid, Patient) or humanoid == self.inverted_patient then
    self:cleanupTreatmentVisuals(humanoid)
  end
  return Room.makeHumanoidLeave(self, humanoid)
end

function UpDownRoom:crashRoom()
  self:cleanupTreatmentVisuals()
  return Room.crashRoom(self)
end

function UpDownRoom:tryToEdit()
  self:cleanupTreatmentVisuals()
  return Room.tryToEdit(self)
end

function UpDownRoom:deactivate()
  self:cleanupTreatmentVisuals()
  return Room.deactivate(self)
end

function UpDownRoom:afterLoad(old, new)
  Room.afterLoad(self, old, new)
  if self.inverted_patient then
    local staff = self.staff_member
    local action = staff and staff.getCurrentAction and staff:getCurrentAction() or nil
    local active_flip = action and action.name == "multi_use_object" and
        action.object and action.object.object_type and
        action.object.object_type.mod_overlay_type == "up_down_big_hands" and
        action.phase == 0 and action.use_with == self.inverted_patient
    if not active_flip then
      self:restorePatientOrientation(self.inverted_patient)
    end
  end
  if not self.is_active or (self.humanoids and self:getPatientCount() == 0) then
    self:cleanupTreatmentVisuals()
  end
end

function UpDownRoom:commandEnteringPatient(patient)
  local staff = self.staff_member
  local rig, stf_x, stf_y = self.world:findObjectNear(patient, "up_down_rig")
  local pat_x, pat_y = rig:getSecondaryUsageTile()

  self.inverted_patient = patient
  staff:setNextAction(WalkAction(stf_x, stf_y))

  local total_ticks = 54
  local tick_budget = total_ticks
  local up_down_loop_callback = --[[persistable:up_down_room_loop_callback]] function(action)
    if action and (action.todo_interrupt or
        (action.use_with and action.use_with.hasLeavingAction and action.use_with:hasLeavingAction())) then
      action:setInvisiblePhaseSpan({99, 100})
      action:setProlongedUsage(false)
      return
    end
    local step = 1
    if staff.animation_idx and TheApp and TheApp.animation_manager and
        TheApp.animation_manager.getAnimLength then
      step = math.max(1, TheApp.animation_manager:getAnimLength(staff.animation_idx) or 1)
    end
    tick_budget = tick_budget - step
    local elapsed = total_ticks - tick_budget
    if action and not ModSprites.hasNativePngAndFlip() then
      if elapsed >= 14 and elapsed < 46 then
        action:setInvisiblePhaseSpan({0, 0})
      else
        action:setInvisiblePhaseSpan({99, 100})
      end
    end
    if tick_budget <= 0 and action then
      action:setInvisiblePhaseSpan({99, 100})
      action:setProlongedUsage(false)
    end
  end

  local up_down_after_use = --[[persistable:up_down_room_after_use]] function()
    self:cleanupTreatmentVisuals(patient)
    staff:setNextAction(MeanderAction())
    self:dealtWithPatient(patient)
  end

  -- Use an out-of-range span {99, 100} so MultiUseObjectAction keeps the patient
  -- visible throughout leg-grab and vertical inversion, while prolonging in_use cleanly.
  staff:queueAction(MultiUseObjectAction(rig, patient):setInvisiblePhaseSpan({99, 100})
      :setProlongedUsage(true):setLoopCallback(up_down_loop_callback):setAfterUse(up_down_after_use))

  patient:setNextAction(WalkAction(pat_x, pat_y))
  patient:queueAction(IdleAction():setDirection(rig.direction == "north" and "east" or "south"))

  return Room.commandEnteringPatient(self, patient)
end

return room
