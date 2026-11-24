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

local ModSprites = require("mod_sprites")

local room = {}
room.id = "quoiging_room"
room.vip_must_visit = false
room.level_config_id = 31
room.class = "QuoigingRoom"
room.name = _S.rooms_short.quoiging_room
room.long_name = _S.rooms_long.quoiging_room
room.tooltip = _S.tooltip.rooms.quoiging_room
room.objects_additional = { "extinguisher", "radiator", "plant", "bin" }
room.objects_needed = { quoiging_chair = 1 }
room.build_preview_animation = 5110
room.categories = {
  clinics = 9,
}
room.minimum_size = 4
room.wall_type = "blue"
room.floor_tile = 17
room.required_staff = {
  Doctor = 1,
}
room.maximum_staff = room.required_staff
room.call_sound = "reqd014.wav"
room.handyman_call_sound = "maint013.wav"

class "QuoigingRoom" (Room)

---@type QuoigingRoom
local QuoigingRoom = _G["QuoigingRoom"]

function QuoigingRoom:QuoigingRoom(...)
  self:Room(...)
end

function QuoigingRoom:clearTreatmentOverlay()
  if not self.objects then
    return
  end
  for object, _ in pairs(self.objects) do
    if object.object_type and object.object_type.id == "quoiging_chair" then
      ModSprites.clearMachineOverlay(object)
    end
  end
end

function QuoigingRoom:onHumanoidEnter(humanoid)
  return Room.onHumanoidEnter(self, humanoid)
end

function QuoigingRoom:onHumanoidLeave(humanoid)
  if class.is(humanoid, Patient) or humanoid == self.staff_member then
    self:clearTreatmentOverlay()
  end
  return Room.onHumanoidLeave(self, humanoid)
end

function QuoigingRoom:makeHumanoidLeave(patient)
  self:clearTreatmentOverlay()
  return Room.makeHumanoidLeave(self, patient)
end

function QuoigingRoom:crashRoom()
  self:clearTreatmentOverlay()
  return Room.crashRoom(self)
end

function QuoigingRoom:tryToEdit()
  self:clearTreatmentOverlay()
  return Room.tryToEdit(self)
end

function QuoigingRoom:deactivate()
  self:clearTreatmentOverlay()
  return Room.deactivate(self)
end

function QuoigingRoom:afterLoad(old, new)
  Room.afterLoad(self, old, new)
  if not self.is_active or (self.humanoids and self:getPatientCount() == 0) then
    self:clearTreatmentOverlay()
  end
end

function QuoigingRoom:commandEnteringPatient(patient)
  local staff = self.staff_member
  local chair, pat_x, pat_y = self.world:findObjectNear(patient, "quoiging_chair")
  local stf_x, stf_y = chair:getSecondaryUsageTile()

  staff:setNextAction(WalkAction(stf_x, stf_y))
  local face_dir = chair.direction == "north" and "north" or "west"
  staff:queueAction(IdleAction():setDirection(face_dir))

  patient:setNextAction(WalkAction(pat_x, pat_y))

  local tick_budget = 42
  local quoiging_loop_callback = --[[persistable:quoiging_room_loop_callback]] function(action)
    if action and (action.todo_interrupt or
        (action.use_with and action.use_with.hasLeavingAction and action.use_with:hasLeavingAction())) then
      action:setProlongedUsage(false)
      return
    end
    local step = 1
    if patient.animation_idx and TheApp and TheApp.animation_manager and
        TheApp.animation_manager.getAnimLength then
      step = math.max(1, TheApp.animation_manager:getAnimLength(patient.animation_idx) or 1)
    end
    tick_budget = tick_budget - step
    if tick_budget <= 0 and action then
      action:setProlongedUsage(false)
    end
  end

  local quoiging_after_use = --[[persistable:quoiging_room_after_use]] function()
    self:clearTreatmentOverlay()
    -- Return the doctor to room meandering if no follow-up action is queued.
    if #staff.action_queue == 1 then
      staff:setNextAction(MeanderAction())
    else
      staff:finishAction(staff:getCurrentAction())
    end
    self:dealtWithPatient(patient)
  end

  patient:queueAction(MultiUseObjectAction(chair, staff):setInvisiblePhaseSpan({99, 100})
      :setProlongedUsage(true):setLoopCallback(quoiging_loop_callback):setAfterUse(quoiging_after_use))

  return Room.commandEnteringPatient(self, patient)
end

return room
