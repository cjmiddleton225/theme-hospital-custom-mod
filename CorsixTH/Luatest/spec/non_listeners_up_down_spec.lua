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

require("class_test_base")
require("corsixth")

describe("Non-Listeners disease and Up-Down Room clinic:", function()
  local saved_S
  local saved_A
  local saved_rooms
  local saved_objects
  local saved_diseases
  local saved_actions
  local saved_random
  local non_listeners
  local whingers
  local uncommon_cold
  local up_down_rig
  local quoiging_chair
  local up_down_room
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

    extracted.diseases = extracted.diseases or {}
    setmetatable(extracted.diseases, {
      __index = function()
        return { name = "Vanilla Disease", cause = "Cause", symptoms = "Symptoms", cure = "Cure" }
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
    non_listeners = require("diseases.non_listeners")
    uncommon_cold = require("diseases.uncommon_cold")
    quoiging_chair = require("objects.machines.quoiging_chair")
    up_down_rig = require("objects.machines.up_down_rig")
    quoiging_room = require("rooms.quoiging_room")
    up_down_room = require("rooms.up_down_room")
    Object.processTypeDefinition(quoiging_chair)
    Object.processTypeDefinition(up_down_rig)

    local pharmacy_room = {
      id = "pharmacy",
      level_config_id = 11,
      objects_needed = {},
      categories = { clinics = 1 },
    }
    TheApp.objects = {
      quoiging_chair = quoiging_chair,
      up_down_rig = up_down_rig,
      quoiging_chair,
      up_down_rig,
    }
    TheApp.rooms = {
      quoiging_room = quoiging_room,
      up_down_room = up_down_room,
      pharmacy = pharmacy_room,
      quoiging_room,
      up_down_room,
      pharmacy_room,
    }
    TheApp.diseases = {
      whingers = whingers,
      non_listeners = non_listeners,
      uncommon_cold = uncommon_cold,
      whingers,
      non_listeners,
      uncommon_cold,
    }
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

  it("defines complete English localization strings for Non-Listeners, Up-Down Room, and Up-Down Rig", function()
    assert.are.equal("Up-Down Room", _S.rooms_short.up_down_room)
    assert.are.equal("Up-Down Room", _S.rooms_long.up_down_room)
    assert.are.equal("A Doctor uses the Up-Down Room to cure patients suffering from Non-Listeners", _S.tooltip.rooms.up_down_room)
    assert.are.equal(3, #_S.room_descriptions.up_down_room)
    assert.are.equal("Up-Down Rig", _S.object.up_down_rig)
    assert.are.equal("Up-Down Rig: Giant-hands inversion rig that flips Non-Listeners upside down until they start listening.", _S.tooltip.objects.up_down_rig)
    assert.are.equal("Non-Listeners", _S.diseases.non_listeners.name)
    assert.truthy(_S.diseases.non_listeners.cause:find("Selective hearing", 1, true))
    assert.truthy(_S.diseases.non_listeners.symptoms:find("Blank stares", 1, true))
    assert.truthy(_S.diseases.non_listeners.cure:find("upside down", 1, true))
  end)

  it("registers Non-Listeners, Up-Down Rig, and Up-Down Room with non-colliding IDs across both custom clinics", function()
    assert.are.equal("non_listeners", non_listeners.id)
    assert.is_nil(non_listeners.visuals_id)
    assert.are.equal(21, non_listeners.non_visuals_id)
    assert.are.equal(48, non_listeners.expertise_id)
    assert.are.same({ "up_down_room" }, non_listeners.treatment_rooms)
    assert.is_true(table_contains(non_listeners.diagnosis_rooms, "general_diag"))
    assert.is_true(table_contains(non_listeners.diagnosis_rooms, "psych"))
    assert.is_false(table_contains(non_listeners.diagnosis_rooms, "gp"))

    assert.are.equal("up_down_rig", up_down_rig.id)
    assert.are.equal(66, up_down_rig.thob)
    assert.are.equal(9, up_down_rig.default_strength)
    assert.truthy(up_down_rig.multi_usage_animations["Doctor - Standard Male Patient"])
    assert.truthy(up_down_rig.multi_usage_animations["Doctor - Standard Female Patient"])

    assert.are.equal("up_down_room", up_down_room.id)
    assert.are.equal("UpDownRoom", up_down_room.class)
    assert.are.equal(32, up_down_room.level_config_id)
    assert.are.equal(10, up_down_room.categories.clinics)
    assert.are.equal(4, up_down_room.minimum_size)
    assert.are.equal(1, up_down_room.objects_needed.up_down_rig)
    assert.are.equal(1, up_down_room.required_staff.Doctor)
    assert.is_nil(up_down_room.required_staff.Surgeon)
    assert.is_nil(up_down_room.required_staff.Psychiatrist)
    assert.is_nil(up_down_room.required_staff.Researcher)

    -- Cross-check uniqueness across Pass 2 and Pass 3 custom entities.
    assert.is_true(quoiging_chair.thob ~= up_down_rig.thob)
    assert.is_true(quoiging_room.level_config_id ~= up_down_room.level_config_id)
    assert.is_true(quoiging_room.categories.clinics ~= up_down_room.categories.clinics)
    assert.is_true(whingers.expertise_id ~= non_listeners.expertise_id)
    assert.is_true(whingers.non_visuals_id ~= non_listeners.non_visuals_id)

    -- Verify base_config allocations for Pass 3.
    assert.are.equal(1, base_config.objects[66].AvailableForLevel)
    assert.are.equal(1, base_config.objects[66].StartAvail)
    assert.are.equal(1400, base_config.rooms[32].Cost)
    assert.are.equal(900, base_config.expertise[48].StartPrice)
    assert.are.equal(1, base_config.non_visuals[21].Value)
    assert.are.equal(0, base_config.non_visuals_available[21].Value)

    -- Verify initPatient supports standard non-visual male and female patients.
    local applied_type
    local applied_layers = {}
    local mock_patient = {
      setType = function(_, t) applied_type = t end,
      setLayer = function(_, layer, val) applied_layers[layer] = val end,
    }
    math.random = function(a) return a end
    non_listeners.initPatient(mock_patient)
    assert.are.equal("Standard Male Patient", applied_type)
    assert.are.equal(0, applied_layers[3])
    assert.are.equal(0, applied_layers[4])

    math.random = function(_, b) return b end
    non_listeners.initPatient(mock_patient)
    assert.are.equal("Standard Female Patient", applied_type)
    assert.are.equal(0, applied_layers[3])
  end)

  it("unlocks both custom rooms and balances Level 1 spawning without starving vanilla diseases", function()
    local level_config = {
      objects = {
        [65] = { StartCost = 1500, StartAvail = 0, WhenAvail = 9, StartStrength = 10, AvailableForLevel = 0 },
        [66] = { StartCost = 1800, StartAvail = 0, WhenAvail = 9, StartStrength = 9, AvailableForLevel = 0 },
      },
      rooms = {
        [11] = { Cost = 500 },
      },
      expertise = {
        [16] = { StartPrice = 300, Known = 1, RschReqd = 20000 },
      },
      non_visuals = {
        [0] = { Value = 1 },
        [20] = { Value = 0 },
        [21] = { Value = 0 },
      },
      non_visuals_available = {
        [0] = { Value = 0 },
      },
    }
    local world = {
      map = { level_config = level_config, level_number = 1 },
      game_date = { monthOfGame = function() return 1 end },
      determineWinningConditions = function() end,
    }
    setmetatable(world, World._metatable)

    world:applyCustomLevelOverrides()
    local avail_rooms = world:getAvailableRooms()
    assert.are.equal(3, #avail_rooms)

    local room_by_id = {}
    for _, entry in ipairs(avail_rooms) do
      room_by_id[entry.room.id] = entry
    end
    assert.is_true(room_by_id.quoiging_room.is_discovered)
    assert.are.equal(2700, room_by_id.quoiging_room.build_cost)
    assert.is_true(room_by_id.up_down_room.is_discovered)
    assert.are.equal(3200, room_by_id.up_down_room.build_cost)

    world:initLevel(TheApp, avail_rooms)
    assert.are.equal(whingers, world.available_diseases.whingers)
    assert.are.equal(non_listeners, world.available_diseases.non_listeners)
    assert.are.equal(uncommon_cold, world.available_diseases.uncommon_cold)
    assert.are.equal(900, world.available_diseases.non_listeners.cure_price)

    -- Roll 0.10 selects Whingers; roll 0.25 selects Non-Listeners; roll 0.75 selects from uniform pool (index 3 = uncommon_cold).
    local next_float
    math.random = function(a, b)
      if a == nil then return next_float end
      return b
    end

    next_float = 0.10
    assert.are.equal(whingers, world:selectDiseaseForNewPatient({ num_visitors = 0 }))

    next_float = 0.25
    assert.are.equal(non_listeners, world:selectDiseaseForNewPatient({ num_visitors = 0 }))

    next_float = 0.75
    assert.are.equal(uncommon_cold, world:selectDiseaseForNewPatient({ num_visitors = 0 }))
  end)

  it("commands doctor and entering patient at up_down_rig and completes treatment", function()
    local patient_actions = {}
    local staff_actions = {}
    local dealt_patient
    local mock_rig = setmetatable({
      direction = "north",
      tile_x = 12,
      tile_y = 12,
      getSecondaryUsageTile = function() return 13, 11 end,
    }, Machine._metatable)
    local mock_staff = {
      setNextAction = function(_, act) staff_actions[1] = act end,
      queueAction = function(_, act) staff_actions[#staff_actions + 1] = act end,
    }
    local mock_patient = setmetatable({
      setNextAction = function(_, act) patient_actions[1] = act end,
      queueAction = function(_, act) patient_actions[#patient_actions + 1] = act end,
      updateDynamicInfo = function() end,
    }, Humanoid._metatable)
    local room = {
      staff_member = mock_staff,
      door = { queue = { visitor_count = 0 } },
      world = {
        findObjectNear = function() return mock_rig, 11, 13 end,
      },
      _staffWaitToggle = function() end,
      dealtWithPatient = function(_, p) dealt_patient = p end,
    }
    local UpDownRoomClass = _G["UpDownRoom"]
    setmetatable(room, UpDownRoomClass._metatable)

    room:commandEnteringPatient(mock_patient)

    assert.are.equal("walk", staff_actions[1].name)
    assert.are.equal("multi_use_object", staff_actions[2].name)
    assert.are.equal(mock_rig, staff_actions[2].object)
    assert.are.equal(mock_patient, staff_actions[2].use_with)
    assert.are.same({ 99, 100 }, staff_actions[2].invisible_phase_span)
    assert.are.equal("walk", patient_actions[1].name)
    assert.are.equal("idle", patient_actions[2].name)

    staff_actions[2].after_use()
    assert.are.equal("meander", staff_actions[1].name)
    assert.are.equal(mock_patient, dealt_patient)
  end)
end)
