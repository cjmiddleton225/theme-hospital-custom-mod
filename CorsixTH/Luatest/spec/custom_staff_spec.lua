--[[ Copyright (c) 2026 CorsixTH Modding Pass 1

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

describe("Custom staff Ella and Dinkles:", function()
  local saved_S
  local saved_A
  local saved_initials_cache
  local saved_humanoid_actions
  local saved_random
  local custom_strings

  local function loadEnglishCustomStaff()
    local candidates = {
      "../Lua/languages/english.lua",
      "CorsixTH/Lua/languages/english.lua",
    }
    local path
    for _, candidate in ipairs(candidates) do
      local fh = io.open(candidate, "r")
      if fh then
        fh:close()
        path = candidate
        break
      end
    end
    assert.truthy(path, "Could not locate english.lua")

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

    local loaded_custom = shadows[shadows[env].custom_staff]
    return {
      ella = {
        name = shadows[loaded_custom.ella].name,
        desc = shadows[loaded_custom.ella].desc,
      },
      dinkles = {
        name = shadows[loaded_custom.dinkles].name,
        desc = shadows[loaded_custom.dinkles].desc,
      },
    }
  end

  local function buildTestStrings(english_custom)
    local sub_S
    sub_S = setmetatable({ key = "" }, {
      __index = function(t, k)
        if k == "__random" then
          return "MOCK"
        end
        t.key = t.key .. "." .. k
        return t
      end,
      __tostring = function(t)
        return t.key
      end,
    })

    local root = {
      custom_staff = english_custom,
      humanoid_name_starts = { __random = "TEST" },
      humanoid_name_ends = { __random = "PERSON" },
      staff_descriptions = {
        bad = { __random = "Bad." },
        good = { __random = "Good." },
        misc = { __random = "Misc." },
      },
      staff_class = {
        doctor = "Doctor",
        nurse = "Nurse",
        handyman = "Handyman",
        receptionist = "Receptionist",
      },
      staff_title = {
        doctor = "Doctor",
        nurse = "Nurse",
        handyman = "Handyman",
        receptionist = "Receptionist",
        junior = "Junior",
        consultant = "Consultant",
        surgeon = "Surgeon",
        psychiatrist = "Psychiatrist",
        researcher = "Researcher",
      },
      dynamic_info = {
        staff = {
          actions = {
            wandering = "Wandering around",
            heading_for = "Heading for %s",
          },
          tiredness = "Tiredness",
          psychiatrist_abbrev = "Psych.",
        },
      },
      object = {
        reception_desk = "Reception Desk",
        litter = "Litter",
      },
      tooltip = {
        objects = {
          reception_desk = "Reception Desk",
          litter = "Litter",
        },
      },
    }

    return setmetatable(root, {
      __index = function(_, k)
        sub_S.key = "_S." .. tostring(k)
        return sub_S
      end,
    })
  end

  local function createBaseLevelConfig()
    return {
      staff = {
        [0] = { MinSalary = 60 },
        [1] = { MinSalary = 75 },
        [2] = { MinSalary = 25 },
        [3] = { MinSalary = 20 },
      },
      staff_levels = {
        [0] = {
          Month = 0,
          Doctors = 2,
          Nurses = 2,
          Handymen = 2,
          Receptionists = 2,
          ShrkRate = 0,
          SurgRate = 0,
          RschRate = 0,
          JrRate = 0,
          ConsRate = 0,
        },
      },
      gbv = {
        DoctorThreshold = 250,
        ConsultantThreshold = 750,
        SalaryAbilityDivisor = 10,
        SalaryAdd = {
          [3] = -30,
          [4] = 30,
          [5] = 40,
          [6] = 30,
          [7] = 100,
          [8] = 20,
        },
        VeryTired = 700,
        CrackUpTired = 800,
      },
      payroll = {
        MaxSalary = 2000,
      },
    }
  end

  local function createTestWorld(level_config)
    local hospital = {
      staff = {},
      policies = { goto_staffroom = 0.6 },
      hosp_cheats = { isCheatActive = function() return false end },
      isInHospital = function() return true end,
      getPlayerIndex = function() return 1 end,
      buildReceptionDesksCache = function() end,
      msgNeedFirstReceptionDesk = function() end,
    }
    local world = {
      app = { config = { language = "english" } },
      map = {
        width = 20,
        height = 20,
        level_config = level_config or createBaseLevelConfig(),
        getRoomId = function() return 0 end,
        th = {
          getCellFlags = function()
            return { passable = true, hospital = true, buildable = true, owner = 1 }
          end,
        },
      },
      hospitals = { hospital },
      rooms = {},
      entities = {},
      objects = {},
      objects_notify_occupants = {},
      available_staff = {},
      debug_disable_salary_raise = true,
      dispatcher = { answerCall = function() return false end },
      ui = { playSound = function() end },
      getLocalPlayerHospital = function() return hospital end,
      getObjectToNotifyOfOccupants = function() return nil end,
      findRoomNear = function() return nil end,
      pathfinder = {
        findIdleTile = function(_, x, y) return x, y end,
        findDistance = function() return 1 end,
      },
    }
    setmetatable(world, World._metatable)
    return world, hospital
  end

  local function makeMockAnim()
    return setmetatable({
      getTile = function() return nil, 5, 5 end,
    }, {
      __index = function() return function() end end,
    })
  end

  local function countCustomStaff(list, custom_id)
    local count = 0
    local found
    for _, profile in ipairs(list) do
      if profile.custom_staff_id == custom_id then
        count = count + 1
        found = profile
      end
    end
    return count, found
  end

  setup(function()
    saved_S = _G._S
    saved_A = _G._A
    saved_initials_cache = _G.staff_initials_cache
    saved_humanoid_actions = _G.TheApp and _G.TheApp.humanoid_actions

    require("TH")
    custom_strings = loadEnglishCustomStaff()
    _G._S = buildTestStrings(custom_strings)

    local sub_A
    sub_A = setmetatable({ key = "" }, {
      __index = function(t) return t end,
      __tostring = function(t) return t.key end,
    })
    _G._A = setmetatable({}, { __index = function() return sub_A end })
    _G.DrawFlags = _G.DrawFlags or {
      BoundBoxHitTest = 1,
    }
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
    require("entity")
    require("entities.humanoid")
    require("entities.object")
    require("entities.machine")
    require("room")
    require("humanoid_action")
    require("humanoid_actions.idle")
    require("humanoid_actions.meander")
    require("humanoid_actions.walk")
    require("humanoid_actions.staff_reception")
    require("objects.litter")
    require("objects.reception_desk")
    require("staff_profile")
    require("world")
    _G.staff_initials_cache = { initials = { [0] = "Z", "A", "B", "C" } }
    _G.TheApp.humanoid_actions = {
      idle = function() end,
      meander = require("humanoid_actions.meander"),
      walk = function() end,
      staff_reception = function() end,
    }
  end)

  teardown(function()
    _G._S = saved_S
    _G._A = saved_A
    _G.staff_initials_cache = saved_initials_cache
    _G.TheApp.humanoid_actions = saved_humanoid_actions
  end)

  before_each(function()
    saved_random = math.random
  end)

  after_each(function()
    math.random = saved_random
  end)

  it("initializes Ella and Dinkles profiles with expected names, bios, and stats", function()
    local world = createTestWorld()

    local ella = StaffProfile(world, "Doctor", _S.staff_class.doctor)
    ella:initCustom("ella")

    assert.are.equal("Ella", ella.name)
    assert.are.equal("", ella.initial)
    assert.are.equal("Ella", ella:getFullName())
    assert.are.equal("Very proficient and hard working, but can't keep her bedroom tidy", ella.desc)
    assert.are.equal(0.92, ella.skill)
    assert.are.equal(0.45, ella.tiredness_rate)
    assert.are.equal(0.95, ella.attention_to_detail)
    assert.are.equal(1, ella.is_consultant)
    assert.is_nil(ella.is_junior)
    assert.are.equal(267, ella.wage)

    local dinkles = StaffProfile(world, "Receptionist", _S.staff_class.receptionist)
    dinkles:initCustom("dinkles")

    assert.are.equal("Dinkles", dinkles.name)
    assert.are.equal("", dinkles.initial)
    assert.are.equal("Dinkles", dinkles:getFullName())
    assert.are.equal("80% Lovely, 20% Doesn't listen, 100% Cute", dinkles.desc)
    assert.are.equal(0.55, dinkles.skill)
    assert.are.equal(0.15, dinkles.attention_to_detail)
    assert.are.equal(75, dinkles.wage)

    -- Normal staff still render with an initial prefix and localiseInitial skips custom staff.
    local standard = StaffProfile(world, "Doctor", _S.staff_class.doctor)
    standard.initial = "A"
    standard.name = "WHITMAN"
    assert.are.equal("A. WHITMAN", standard:getFullName())

    ella.name_lang = "other"
    dinkles.name_lang = "other"
    world:localiseInitial(ella)
    world:localiseInitial(dinkles)
    assert.are.equal("", ella.initial)
    assert.are.equal("", dinkles.initial)
  end)

  it("guarantees Ella and Dinkles in the initial month 0 hire pool without duplicating them", function()
    local world, hospital = createTestWorld()
    world:makeAvailableStaff(0)

    local ella_count, ella = countCustomStaff(world.available_staff.Doctor, "ella")
    assert.are.equal(1, ella_count)
    assert.are.equal("Ella", ella:getFullName())
    assert.are.equal("Very proficient and hard working, but can't keep her bedroom tidy", ella.desc)
    assert.are.equal(0.92, ella.skill)
    assert.are.equal(0.45, ella.tiredness_rate)
    assert.are.equal(0.95, ella.attention_to_detail)

    local dinkles_count, dinkles = countCustomStaff(world.available_staff.Receptionist, "dinkles")
    assert.are.equal(1, dinkles_count)
    assert.are.equal("Dinkles", dinkles:getFullName())
    assert.are.equal("80% Lovely, 20% Doesn't listen, 100% Cute", dinkles.desc)
    assert.are.equal(0.55, dinkles.skill)
    assert.are.equal(0.15, dinkles.attention_to_detail)

    -- Calling ensureCustomAvailableStaff again does not duplicate pool entries.
    world:ensureCustomAvailableStaff()
    assert.are.equal(1, countCustomStaff(world.available_staff.Doctor, "ella"))
    assert.are.equal(1, countCustomStaff(world.available_staff.Receptionist, "dinkles"))

    -- Once hired, subsequent monthly pool refreshes do not re-add them.
    hospital.staff = {
      { profile = ella },
      { profile = dinkles },
    }
    world:makeAvailableStaff(1)
    assert.are.equal(0, countCustomStaff(world.available_staff.Doctor, "ella"))
    assert.are.equal(0, countCustomStaff(world.available_staff.Receptionist, "dinkles"))
  end)

  it("applies Ella's lower tiredness rate, litter mood immunity, and capped litter drops", function()
    local world, hospital = createTestWorld()

    local function makeDoctor(custom_id)
      local doc = Doctor(makeMockAnim())
      doc.world = world
      doc.hospital = hospital
      doc.tile_x = 5
      doc.tile_y = 5
      doc.action_queue = { { name = "idle" } }
      doc.attributes = { fatigue = 0, happiness = 0.8, warmth = 0.5 }
      doc.findObjectsInSquare = function() return {} end
      doc.getRoom = function() return { room_info = { id = "gp" }, x = 4, y = 4, width = 4, height = 4 } end
      local profile = StaffProfile(world, "Doctor", _S.staff_class.doctor)
      if custom_id then
        profile:initCustom(custom_id)
      else
        profile:initDoctor(0, 0, 0, nil, 1, 0.92)
      end
      doc:setProfile(profile)
      return doc
    end

    local ella_doc = makeDoctor("ella")
    local regular_doc = makeDoctor(nil)

    ella_doc.litter_quirk_cooldown = 100
    ella_doc:tick()
    regular_doc:tick()
    assert.is_true(ella_doc:getAttribute("fatigue") < regular_doc:getAttribute("fatigue"))
    assert.is_true(math.abs(ella_doc:getAttribute("fatigue") - regular_doc:getAttribute("fatigue") * 0.45) < 1e-9)

    -- Regular trash reduces normal doctor's happiness but does not bother Ella.
    local mock_trash = { anyLitter = function() return true end }
    ella_doc.findObjectsInSquare = function() return { mock_trash } end
    regular_doc.findObjectsInSquare = function() return { mock_trash } end
    ella_doc.attributes.happiness = 0.8
    regular_doc.attributes.happiness = 0.8
    ella_doc.litter_quirk_cooldown = 100
    ella_doc:tick()
    regular_doc:tick()
    assert.is_true(ella_doc:getAttribute("happiness") > regular_doc:getAttribute("happiness"))

    -- Litter drop quirk creates a Litter object via world:newObject and respects the room cap.
    local dropped = {}
    local objects_by_coord = {}
    local function coordKey(x, y) return x .. "," .. y end
    world.getObjects = function(_, x, y)
      return objects_by_coord[coordKey(x, y)]
    end
    world.getObject = function(_, x, y, id)
      local list = objects_by_coord[coordKey(x, y)]
      if not list then return nil end
      for _, obj in ipairs(list) do
        if obj.object_type and obj.object_type.id == id then
          return obj
        end
      end
      return nil
    end
    world.newObject = function(_, id, x, y)
      local litter_obj = {
        object_type = { id = id },
        tile_x = x,
        tile_y = y,
        setLitterType = function(self, kind, mirror)
          self.litter_kind = kind
          self.mirror = mirror
        end,
      }
      objects_by_coord[coordKey(x, y)] = { litter_obj }
      dropped[#dropped + 1] = litter_obj
      return litter_obj
    end

    math.random = function(a, b)
      if a == nil then return 0.1 end
      return a
    end

    ella_doc.litter_quirk_cooldown = 1
    assert.is_true(ella_doc:maybeDropCustomLitter())
    assert.are.equal(1, #dropped)
    assert.are.equal("litter", dropped[1].object_type.id)
    assert.are.equal(1, dropped[1].litter_kind)

    -- Tile already has an object -> blocked.
    ella_doc.litter_quirk_cooldown = 1
    assert.is_false(ella_doc:maybeDropCustomLitter())
    assert.are.equal(1, #dropped)

    -- Room already has 3 litter objects -> capped even on an empty tile.
    objects_by_coord[coordKey(6, 5)] = { { object_type = { id = "litter" } } }
    objects_by_coord[coordKey(6, 6)] = { { object_type = { id = "litter" } } }
    ella_doc.tile_x = 5
    ella_doc.tile_y = 6
    ella_doc.litter_quirk_cooldown = 1
    assert.is_false(ella_doc:maybeDropCustomLitter())
    assert.are.equal(1, #dropped)
  end)

  it("gives Dinkles a bounded placement quirk that recovers cleanly to reception duties", function()
    local world, hospital = createTestWorld()
    local dinkles = Receptionist(makeMockAnim())
    dinkles.world = world
    dinkles.hospital = hospital
    dinkles.tile_x = 8
    dinkles.tile_y = 8
    dinkles.action_queue = { { name = "idle" } }
    dinkles.attributes = { happiness = 0.8, warmth = 0.5 }
    dinkles.findObjectsInSquare = function() return {} end
    dinkles.setTile = function(self, x, y)
      self.tile_x = x
      self.tile_y = y
    end

    local profile = StaffProfile(world, "Receptionist", _S.staff_class.receptionist)
    profile:initCustom("dinkles")
    dinkles:setProfile(profile)

    local desk = {
      world = world,
      tile_x = 8,
      tile_y = 8,
      object_type = { id = "reception_desk" },
      getSecondaryUsageTile = function() return 8, 9 end,
      occupy = function(self, rec)
        self.reserved_for = rec
        rec.associated_desk = self
        return true
      end,
    }
    setmetatable(desk, ReceptionDesk._metatable)

    world.entities = { dinkles }
    world.getObject = function(_, x, y, id)
      if id == "reception_desk" and x == 8 and y == 8 then
        return desk
      end
      return nil
    end
    world.findObjectNear = function(_, humanoid, obj_name, _, _, cb)
      if obj_name == "reception_desk" then
        cb(8, 8)
      end
    end

    -- Trigger the 25% quirk when dropped on the desk tile.
    math.random = function(a, b)
      if a == nil then return 0.1 end
      return a
    end

    dinkles:onPlaceInCorridor()
    assert.are.equal(8, dinkles.tile_x)
    assert.are.equal(9, dinkles.tile_y)
    assert.are.equal(40, dinkles.dinkles_meander_ticks)
    assert.is_true(dinkles.dinkles_just_ignored)
    assert.is_nil(desk.reserved_for)
    assert.is_false(desk:checkForNearbyStaff())

    -- After meandering finishes, Dinkles automatically seeks and occupies the desk.
    for _ = 1, 40 do
      dinkles:tick()
    end
    assert.is_nil(dinkles.dinkles_meander_ticks)
    assert.are.equal(dinkles, desk.reserved_for)
    assert.are.equal(desk, dinkles.associated_desk)

    -- A second consecutive drop will not ignore again.
    desk.reserved_for = nil
    dinkles.associated_desk = nil
    dinkles:onPlaceInCorridor()
    assert.is_nil(dinkles.dinkles_meander_ticks)
    assert.is_nil(dinkles.dinkles_just_ignored)
    assert.are.equal(dinkles, desk.reserved_for)
  end)
end)
