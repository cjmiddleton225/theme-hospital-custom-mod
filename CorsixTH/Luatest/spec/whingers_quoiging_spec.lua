--[[ Copyright (c) 2026 CorsixTH Modding Pass 2

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

require("class_test_base")
require("corsixth")

describe("Whingers disease and Quoiging Room clinic:", function()
  local saved_S
  local saved_A
  local saved_rooms
  local saved_objects
  local saved_diseases
  local saved_actions
  local saved_random
  local whingers
  local quoiging_chair
  local quoiging_room
  local base_config

  local function findLuaFile(relative_to_lua)
    local candidates = {
      "../Lua/" .. relative_to_lua,
      "CorsixTH/Lua/" .. relative_to_lua,
    }
    for _, candidate in ipairs(candidates) do
      local fh = io.open(candidate, "r")
      if fh then
        fh:close()
        return candidate
      end
    end
    error("Could not locate " .. relative_to_lua)
  end

  local function loadEnglishStrings()
    local path = findLuaFile("languages/english.lua")
    local env = {}
    local shadows = { [env] = {} }
    local metatable
    local functions = {
      Font = function() end,
      Language = function() end,
      Inherit = function() end,
      IsArabicNumerals = function() end,
      utf8 = function(s) return s end,
      cp437 = function(s) return s end,
      pairs = pairs,
      ipairs = ipairs,
      type = type,
      _G = env,
    }
    metatable = {
      __index = function(t, k)
        local shadow = shadows[t]
        local value = ((t == env) and functions[k]) or shadow[k]
        if value == nil then
          value = setmetatable({}, metatable)
          shadow[k] = value
          shadows[value] = {}
        end
        return value
      end,
      __newindex = function(t, k, v)
        if type(v) ~= "table" then
          shadows[t][k] = v
        else
          local sub = t[k]
          for k2, v2 in pairs(v) do
            sub[k2] = v2
          end
        end
      end,
    }
    setmetatable(env, metatable)
    local chunk, err = loadfile(path, "t", env)
    assert.truthy(chunk, err)
    chunk()

    local function unwrap(node)
      local s = shadows[node]
      if not s then return node end
      local out = {}
      for k, v in pairs(s) do
        if type(v) == "table" and shadows[v] then
          out[k] = unwrap(v)
        else
          out[k] = v
        end
      end
      return out
    end

    local extracted = unwrap(env)
    local sub_S
    sub_S = setmetatable({ key = "" }, {
      __index = function(t, k)
        t.key = t.key .. "." .. tostring(k)
        return t
      end,
      __tostring = function(t)
        return t.key
      end,
    })

    extracted.humanoid_name_starts = extracted.humanoid_name_starts or { __random = "TEST" }
    extracted.humanoid_name_ends = extracted.humanoid_name_ends or { __random = "PERSON" }
    extracted.staff_descriptions = extracted.staff_descriptions or {}
    extracted.staff_descriptions.bad = extracted.staff_descriptions.bad or { __random = "Bad." }
    extracted.staff_descriptions.good = extracted.staff_descriptions.good or { __random = "Good." }
    extracted.staff_descriptions.misc = extracted.staff_descriptions.misc or { __random = "Misc." }
    extracted.staff_class = extracted.staff_class or {
      doctor = "Doctor",
      nurse = "Nurse",
      handyman = "Handyman",
      receptionist = "Receptionist",
    }
    extracted.dynamic_info = extracted.dynamic_info or {
      staff = { actions = { waiting_for_patient = "Waiting" } },
      object = { queue_size = "%d", queue_expected = "%d" },
      patient = { actions = { cured = "Cured" } },
    }
    extracted.build_room_window = extracted.build_room_window or {
      cost = "Cost: $",
    }

    return setmetatable(extracted, {
      __index = function(_, k)
        sub_S.key = "_S." .. tostring(k)
        return sub_S
      end,
    })
  end

  local function loadBaseConfig()
    local path = findLuaFile("base_config.lua")
    local chunk, err = loadfile(path)
    assert.truthy(chunk, err)
    return chunk()
  end

  setup(function()
    saved_S = _G._S
    saved_A = _G._A
    saved_rooms = TheApp and TheApp.rooms
    saved_objects = TheApp and TheApp.objects
    saved_diseases = TheApp and TheApp.diseases
    saved_actions = TheApp and TheApp.humanoid_actions

    require("TH")
    _G._S = loadEnglishStrings()
    local sub_A
    sub_A = setmetatable({ key = "" }, {
      __index = function(t) return t end,
      __tostring = function(t) return t.key end,
    })
    _G._A = setmetatable({}, { __index = function() return sub_A end })
    _G.DrawingLayers = _G.DrawingLayers or {
      ReceptionistFacingAway = 1,
      ReceptionistFacingUser = 1,
      Litter = 1,
    }
    _G.AnnouncementPriority = _G.AnnouncementPriority or {
      High = 2,
      Critical = 4,
    }

    require("utility")
    require("map")
    require("entity")
    require("entities.humanoid")
    require("entities.object")
    require("entities.machine")
    require("room")
    require("humanoid_action")
    require("humanoid_actions.idle")
    require("humanoid_actions.meander")
    require("humanoid_actions.walk")
    require("humanoid_actions.multi_use_object")
    require("staff_profile")
    require("world")

    base_config = loadBaseConfig()
    whingers = require("diseases.whingers")
    quoiging_chair = require("objects.machines.quoiging_chair")
    quoiging_room = require("rooms.quoiging_room")
    Object.processTypeDefinition(quoiging_chair)

    TheApp.objects = { quoiging_chair = quoiging_chair, quoiging_chair }
    TheApp.rooms = { quoiging_room = quoiging_room, quoiging_room }
    TheApp.diseases = { whingers = whingers, whingers }
  end)

  teardown(function()
    _G._S = saved_S
    _G._A = saved_A
    if TheApp then
      TheApp.rooms = saved_rooms
      TheApp.objects = saved_objects
      TheApp.diseases = saved_diseases
      TheApp.humanoid_actions = saved_actions
    end
  end)

  before_each(function()
    saved_random = math.random
  end)

  after_each(function()
    math.random = saved_random
  end)

  it("defines complete English localization strings for Whingers, Quoiging Room, and Quoiging Chair", function()
    assert.are.equal("Quoiging Room", _S.rooms_short.quoiging_room)
    assert.are.equal("Quoiging Room", _S.rooms_long.quoiging_room)
    assert.are.equal("A Doctor uses the Quoiging Room to cure patients suffering from Whingers", _S.tooltip.rooms.quoiging_room)
    assert.are.equal(3, #_S.room_descriptions.quoiging_room)
    assert.are.equal("Quoiging Chair", _S.object.quoiging_chair)
    assert.are.equal("Quoiging Chair: Fitted with big red tickling hands for curing Whingers.", _S.tooltip.objects.quoiging_chair)
    assert.are.equal("Whingers", _S.diseases.whingers.name)
    assert.truthy(_S.diseases.whingers.cause:find("complaining", 1, true))
    assert.truthy(_S.diseases.whingers.symptoms:find("moaning", 1, true))
    assert.truthy(_S.diseases.whingers.cure:find("big red hands", 1, true))
  end)

  it("registers non-visual Whingers disease, Quoiging Chair machine, and Quoiging Room without ID collisions", function()
    assert.are.equal("whingers", whingers.id)
    assert.is_nil(whingers.visuals_id)
    assert.are.equal(20, whingers.non_visuals_id)
    assert.are.equal(47, whingers.expertise_id)
    assert.are.same({ "quoiging_room" }, whingers.treatment_rooms)
    assert.is_true(table_contains(whingers.diagnosis_rooms, "general_diag"))
    assert.is_true(table_contains(whingers.diagnosis_rooms, "psych"))
    assert.is_false(table_contains(whingers.diagnosis_rooms, "gp"))

    assert.are.equal("quoiging_chair", quoiging_chair.id)
    assert.are.equal(65, quoiging_chair.thob)
    assert.are.equal(10, quoiging_chair.default_strength)
    assert.truthy(quoiging_chair.multi_usage_animations["Standard Male Patient - Doctor"])
    assert.truthy(quoiging_chair.multi_usage_animations["Standard Female Patient - Doctor"])

    assert.are.equal("quoiging_room", quoiging_room.id)
    assert.are.equal("QuoigingRoom", quoiging_room.class)
    assert.are.equal(31, quoiging_room.level_config_id)
    assert.are.equal(9, quoiging_room.categories.clinics)
    assert.are.equal(4, quoiging_room.minimum_size)
    assert.are.equal(1, quoiging_room.objects_needed.quoiging_chair)
    assert.are.equal(1, quoiging_room.required_staff.Doctor)
    assert.is_nil(quoiging_room.required_staff.Surgeon)
    assert.is_nil(quoiging_room.required_staff.Psychiatrist)
    assert.is_nil(quoiging_room.required_staff.Researcher)

    -- Verify base_config allocates the matching non-colliding indices.
    assert.are.equal(1, base_config.objects[65].AvailableForLevel)
    assert.are.equal(1, base_config.objects[65].StartAvail)
    assert.are.equal(1200, base_config.rooms[31].Cost)
    assert.are.equal(800, base_config.expertise[47].StartPrice)
    assert.are.equal(1, base_config.non_visuals[20].Value)
    assert.are.equal(0, base_config.non_visuals_available[20].Value)

    -- Verify initPatient supports standard non-visual male and female patients.
    local applied_type
    local applied_layers = {}
    local mock_patient = {
      setType = function(_, t) applied_type = t end,
      setLayer = function(_, layer, val) applied_layers[layer] = val end,
    }
    math.random = function(a) return a end
    whingers.initPatient(mock_patient)
    assert.are.equal("Standard Male Patient", applied_type)
    assert.are.equal(0, applied_layers[3])
    assert.are.equal(0, applied_layers[4])

    math.random = function(_, b) return b end
    whingers.initPatient(mock_patient)
    assert.are.equal("Standard Female Patient", applied_type)
    assert.are.equal(0, applied_layers[3])
  end)

  it("unlocks Quoiging Room and Whingers on Level 1 via World:applyCustomLevelOverrides and boosts Whingers spawn", function()
    local level_config = {
      objects = {
        [65] = { StartCost = 1500, StartAvail = 0, WhenAvail = 9, StartStrength = 10, AvailableForLevel = 0 },
      },
      rooms = {},
      expertise = {},
      non_visuals = {
        [20] = { Value = 0 },
      },
      non_visuals_available = {},
    }
    local world = {
      map = { level_config = level_config, level_number = 1 },
      game_date = { monthOfGame = function() return 1 end },
      determineWinningConditions = function() end,
    }
    setmetatable(world, World._metatable)

    world:applyCustomLevelOverrides()
    local avail_rooms = world:getAvailableRooms()
    assert.are.equal(1, #avail_rooms)
    assert.are.equal("quoiging_room", avail_rooms[1].room.id)
    assert.is_true(avail_rooms[1].is_discovered)
    assert.are.equal(2700, avail_rooms[1].build_cost)

    world:initLevel(TheApp, avail_rooms)
    assert.are.equal(whingers, world.available_diseases.whingers)
    assert.are.equal(800, world.available_diseases.whingers.cure_price)

    -- Boosted selection returns Whingers when random < 0.30.
    math.random = function(a)
      if a == nil then return 0.1 end
      return a
    end
    local picked = world:selectDiseaseForNewPatient({ num_visitors = 0 })
    assert.are.equal(whingers, picked)
  end)

  it("commands entering patient and doctor at quoiging_chair and calls dealtWithPatient on completion", function()
    local queued_actions = {}
    local dealt_patient
    local staff_actions = {}
    local mock_chair = setmetatable({
      direction = "north",
      tile_x = 10,
      tile_y = 10,
      getSecondaryUsageTile = function() return 11, 9 end,
    }, Machine._metatable)
    local mock_staff = setmetatable({
      action_queue = { { name = "use_object" } },
      setNextAction = function(self, act)
        staff_actions[#staff_actions + 1] = act
        self.action_queue = { act }
      end,
      queueAction = function(self, act)
        staff_actions[#staff_actions + 1] = act
        self.action_queue[#self.action_queue + 1] = act
      end,
      getCurrentAction = function(self) return self.action_queue[1] end,
      finishAction = function() end,
    }, Doctor._metatable)
    local mock_patient = {
      setNextAction = function(_, act) queued_actions[1] = act end,
      queueAction = function(_, act) queued_actions[#queued_actions + 1] = act end,
      updateDynamicInfo = function() end,
    }
    local room = {
      staff_member = mock_staff,
      door = { queue = { visitor_count = 0 } },
      world = {
        findObjectNear = function() return mock_chair, 9, 10 end,
      },
      _staffWaitToggle = function() end,
      dealtWithPatient = function(_, p) dealt_patient = p end,
    }
    local QuoigingRoomClass = _G["QuoigingRoom"]
    setmetatable(room, QuoigingRoomClass._metatable)

    room:commandEnteringPatient(mock_patient)

    assert.are.equal("walk", staff_actions[1].name)
    assert.are.equal("idle", staff_actions[2].name)
    assert.are.equal("walk", queued_actions[1].name)
    assert.are.equal("multi_use_object", queued_actions[2].name)
    assert.are.equal(mock_chair, queued_actions[2].object)
    assert.are.equal(mock_staff, queued_actions[2].use_with)

    -- Simulate WalkAction finishing so IdleAction is active when MultiUseObjectAction ends.
    mock_staff.action_queue = { staff_actions[2] }
    -- Trigger persistable after_use callback.
    queued_actions[2].after_use()
    assert.are.equal("meander", staff_actions[#staff_actions].name)
    assert.are.equal(mock_patient, dealt_patient)
  end)
end)
