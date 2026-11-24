--[[ Copyright (c) 2009 Peter "Corsix" Cawley

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

corsixth.require("announcer")
corsixth.require("entities.humanoids.staff")

local AnnouncementPriority = _G["AnnouncementPriority"]

local DINKLES_IGNORE_CHANCE = 0.25
local DINKLES_MEANDER_MIN_TICKS = 40
local DINKLES_MEANDER_MAX_TICKS = 80

--! A Doctor, Nurse, Receptionist, Handyman, or Surgeon
class "Receptionist" (Staff)

---@type Receptionist
local Receptionist = _G["Receptionist"]

--!param ... Arguments to base class constructor.
function Receptionist:Receptionist(...)
  self:Staff(...)
  self.leave_sounds = {"sack007.wav", "sack008.wav"}
  self.leave_priority = AnnouncementPriority.Critical -- must always be played even without receptionist
end

function Receptionist:tickDay()
  if not Staff.tickDay(self) then
    return false
  end
  self:needsWorkStation()
end

function Receptionist:isTiring()
  return false
end

function Receptionist:isResting()
  return false
end

function Receptionist:setProfile(profile)
  Staff.setProfile(self, profile)
  self.attributes["fatigue"] = nil
end

function Receptionist:needsWorkStation()
  if self.hospital then
    self.hospital:msgNeedFirstReceptionDesk()
  end
end

-- Receptionists do not need rest
function Receptionist:checkIfNeedRest()
  return
end

--! Search for an unstaffed reception desk and assign this receptionist to it.
function Receptionist:seekAvailableReceptionDesk()
  local world = self.world
  local found_desk = false
  world:findObjectNear(self, "reception_desk", nil, true, function(x, y)
    local obj = world:getObject(x, y, "reception_desk")
    if obj and obj:occupy(self) then
      found_desk = true
      return true
    end
  end)
  if found_desk then
    self:setDynamicInfoText("")
  end
  if self.hospital then
    self.hospital:buildReceptionDesksCache() -- Rebuild cache of staffed desks
  end
end

--! Decide whether custom receptionist Dinkles ignores the current placement once.
--!return (boolean) True if he should meander briefly before taking a desk.
function Receptionist:shouldIgnorePlacement()
  return self.profile and self.profile.custom_staff_id == "dinkles" and
      not self.dinkles_just_ignored and math.random() < DINKLES_IGNORE_CHANCE
end

function Receptionist:tick()
  Staff.tick(self)
  if self.fired or self.pickup or not self.hospital or self.dead then
    return
  end
  if self.dinkles_meander_ticks then
    self.dinkles_meander_ticks = self.dinkles_meander_ticks - 1
    if self.dinkles_meander_ticks <= 0 then
      self.dinkles_meander_ticks = nil
      self:seekAvailableReceptionDesk()
    end
  end
end

function Receptionist:onPlaceInCorridor()
  self.dinkles_meander_ticks = nil
  if self:shouldIgnorePlacement() then
    local desk = self.world:getObject(self.tile_x, self.tile_y, "reception_desk")
    if desk then
      local ux, uy = desk:getSecondaryUsageTile()
      self:setTile(ux, uy)
    end
    local flags = self.world.map.th:getCellFlags(self.tile_x, self.tile_y)
    if flags and flags.passable then
      Staff.onPlaceInCorridor(self)
      self.dinkles_meander_ticks = math.random(DINKLES_MEANDER_MIN_TICKS, DINKLES_MEANDER_MAX_TICKS)
      self.dinkles_just_ignored = true
      self:setDynamicInfoText(_S.dynamic_info.staff.actions.wandering)
      if self.hospital then
        self.hospital:buildReceptionDesksCache()
      end
      return
    end
  end

  self.dinkles_just_ignored = nil
  Staff.onPlaceInCorridor(self)
  self:seekAvailableReceptionDesk()
end


-- Helper function to decide if Staff fulfills a criterion
-- (one of "Doctor", "Nurse", "Psychiatrist", "Surgeon", "Researcher" and "Handyman", "Receptionist", "Junior", "Consultant")
function Receptionist:fulfillsCriterion(criterion)
  return criterion == "Receptionist"
end

function Receptionist:getDrawingLayer()
  local direction = self.last_move_direction
  if direction == "west" or direction == "north" then
    return DrawingLayers.ReceptionistFacingAway
  end
  return DrawingLayers.ReceptionistFacingUser
end

function Receptionist:onPickup()
  Staff.onPickup(self)
  self.dinkles_meander_ticks = nil
  self.hospital:buildReceptionDesksCache() -- Rebuild cache of staffed desks
end

function Receptionist:fire()
  Staff.fire(self)
  self.hospital:buildReceptionDesksCache() -- Rebuild cache of staffed desks
end

function Receptionist:afterLoad(old, new)
  if old < 163 then
    self.leave_sounds = {"sack007.wav", "sack008.wav"}
    self.leave_priority = AnnouncementPriority.Critical -- must always be played even without receptionist
  end
  Staff.afterLoad(self, old, new)
end
