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

require("class_test_base")
require("corsixth")

describe("Pass 4 custom machines, tickle/hat/leg-dangle animations, and vertical flip:", function()
  local saved_S
  local saved_A
  local saved_TH
  local saved_gfx
  local saved_getFullPath
  local saved_getBitmapDir

  local ModSprites
  local quoiging_chair
  local up_down_rig

  local function findModSpritesDir()
    local candidates = {
      "../Bitmap/mod_sprites/",
      "CorsixTH/Bitmap/mod_sprites/",
    }
    for _, candidate in ipairs(candidates) do
      local fh = io.open(candidate .. "mod_sprites.tab", "rb")
      if fh then
        fh:close()
        return candidate
      end
    end
    error("Could not locate CorsixTH/Bitmap/mod_sprites directory")
  end

  local function createMockSurface()
    return {}
  end

  setup(function()
    saved_S = _G._S
    saved_A = _G._A
    saved_TH = package.loaded["TH"]
    saved_gfx = TheApp and TheApp.gfx
    saved_getFullPath = TheApp and TheApp.getFullPath
    saved_getBitmapDir = TheApp and TheApp.getBitmapDir

    local TH = require("TH")
    TH.palette = TH.palette or function(data, pal8)
      return {
        data = data,
        pal8 = pal8,
        entries = {},
        setEntry = function(self, idx, r, g, b)
          self.entries[idx] = { r, g, b }
        end,
      }
    end
    TH.sheet = TH.sheet or function()
      return {
        setPalette = function(self, pal) self.palette = pal end,
        load = function(self, tab, dat, complex, target)
          self.loaded_fallback = { tab = #tab, dat = #dat, complex = complex, target = target }
          return true
        end,
      }
    end
    TH.spriteList = function()
      local inst = {
        sprites = {},
        tiles = {},
        flags = 0,
        pos_x = 0,
        pos_y = 0,
        setSheet = function(self, sheet) self.sheet = sheet; return self end,
        append = function(self, idx, x, y)
          self.sprites[#self.sprites + 1] = { idx = idx, x = x, y = y }
          return self
        end,
        setPosition = function(self, x, y)
          self.pos_x = x
          self.pos_y = y
          return self
        end,
        setFlag = function(self, f)
          self.flags = f
          return self
        end,
        setTile = function(self, map_th, tx, ty, layer)
          if map_th == nil then
            self.detached = true
            self.tile_x = nil
            self.tile_y = nil
          else
            self.detached = false
            self.tile_x = tx
            self.tile_y = ty
            self.layer = layer
          end
          self.tiles[#self.tiles + 1] = { map_th = map_th, tx = tx, ty = ty, layer = layer }
          return self
        end,
      }
      return inst
    end

    _G._S = setmetatable({
      rooms_short = { quoiging_room = "Quoiging Room", up_down_room = "Up-Down Room" },
      rooms_long = { quoiging_room = "Quoiging Room", up_down_room = "Up-Down Room" },
      tooltip = { rooms = {}, objects = {} },
      object = { quoiging_chair = "Quoiging Chair", up_down_rig = "Up-Down Rig" },
      room_descriptions = { quoiging_room = {}, up_down_room = {} },
      dynamic_info = {
        object = { strength = "%d", strength_extra_info = "%d/%d", times_used = "%d" },
      },
    }, {
      __index = function() return setmetatable({}, { __index = function() return "" end }) end,
    })
    _G._A = setmetatable({}, { __index = function() return {} end })
    _G.DrawingLayers = _G.DrawingLayers or {
      NorthSideObject = 1,
      AtomAnalyser = 3,
      Entity = 4,
      MachineSmoke = 6,
      FloatingDollars = 7,
    }

    require("utility")
    require("graphics")
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

    ModSprites = require("mod_sprites")
    quoiging_chair = require("objects.machines.quoiging_chair")
    up_down_rig = require("objects.machines.up_down_rig")
    Object.processTypeDefinition(quoiging_chair)
    Object.processTypeDefinition(up_down_rig)
    require("rooms.quoiging_room")
    require("rooms.up_down_room")
  end)

  teardown(function()
    _G._S = saved_S
    _G._A = saved_A
    package.loaded["TH"] = saved_TH
    if TheApp then
      TheApp.gfx = saved_gfx
      TheApp.getFullPath = saved_getFullPath
      TheApp.getBitmapDir = saved_getBitmapDir
    end
  end)

  it("provides all 24 crisp RGBA PNG frames and matching 144-byte compiled fallback sheet files", function()
    local dir = findModSpritesDir()
    local png_magic = "\137PNG\r\n\26\n"

    assert.are.equal(24, #ModSprites.FRAME_FILES)
    for _, fname in ipairs(ModSprites.FRAME_FILES) do
      local fh = io.open(dir .. fname, "rb")
      assert.truthy(fh, "Missing PNG asset: " .. fname)
      local data = fh:read("*a")
      fh:close()
      assert.is_true(#data > 100, "PNG asset unexpectedly small: " .. fname)
      assert.are.equal(png_magic, data:sub(1, 8), "Invalid PNG header on " .. fname)
    end

    local pal = assert(io.open(dir .. "mod_sprites.pal", "rb"))
    assert.are.equal(768, #pal:read("*a"))
    pal:close()

    local tab = assert(io.open(dir .. "mod_sprites.tab", "rb"))
    assert.are.equal(24 * 6, #tab:read("*a"))
    tab:close()

    local dat = assert(io.open(dir .. "mod_sprites.dat", "rb"))
    assert.is_true(#dat:read("*a") > 1000)
    dat:close()
  end)

  it("loads 24 custom sprites via native PNGs or falls back cleanly to .pal/.tab/.dat", function()
    local dir = findModSpritesDir()
    local native_paths
    local TH = require("TH")
    local orig_sheet = TH.sheet

    TH.sheet = function()
      return {
        loadPNGs = function(self, paths, target)
          native_paths = paths
          self.native_loaded = #paths
          self.target = target
          return true
        end,
      }
    end
    local app = {
      video = createMockSurface(),
      config = {},
      strings = {},
      getFullPath = function(_, folders)
        if folders[1] == "Bitmap" and folders[2] == "mod_sprites" then
          return dir
        end
        return ""
      end,
      readDataFile = function() return string.rep("\0", 768) end,
    }
    local gfx = setmetatable({
      app = app,
      target = app.video,
      cache = { tabled = {}, raw = {}, palette = {}, anims = {}, ghosts = {}, language_fonts = {}, cursors = {} },
      reload_functions = {},
      reload_functions_last = {},
      load_info = {},
    }, Graphics._metatable)

    local native_sheet = gfx:loadModSprites("mod_sprites")
    assert.truthy(native_sheet)
    assert.is_true(gfx.has_native_mod_pngs)
    assert.are.equal(24, #native_paths)
    assert.are.equal(gfx.loadModSprites, gfx.load_info[native_sheet][1])
    assert.are.equal("mod_sprites", gfx.load_info[native_sheet][3])

    TH.sheet = orig_sheet
    local gfx_fb = setmetatable({
      app = app,
      target = app.video,
      cache = { tabled = {}, raw = {}, palette = {}, anims = {}, ghosts = {}, language_fonts = {}, cursors = {} },
      reload_functions = {},
      reload_functions_last = {},
      load_info = {},
    }, Graphics._metatable)
    local fb_sheet = gfx_fb:loadModSprites("mod_sprites")
    assert.truthy(fb_sheet)
    assert.is_false(gfx_fb.has_native_mod_pngs)
    assert.are.equal(144, fb_sheet.loaded_fallback.tab)
    assert.is_false(fb_sheet.loaded_fallback.complex)
  end)

  it("renders custom Quoiging Chair sprite, tickle-and-laugh overlay, patient bounce, and doctor silly hat", function()
    local dir = findModSpritesDir()
    TheApp.getFullPath = function(_, folders)
      if folders[1] == "Bitmap" and folders[2] == "mod_sprites" then return dir end
      return ""
    end
    TheApp.gfx = setmetatable({
      app = TheApp,
      target = createMockSurface(),
      cache = { tabled = {}, raw = {}, palette = {}, anims = {}, ghosts = {}, language_fonts = {}, cursors = {} },
      reload_functions = {},
      reload_functions_last = {},
      load_info = {},
    }, Graphics._metatable)

    assert.is_true(quoiging_chair.ticks)
    assert.are.equal("quoiging_chair", quoiging_chair.mod_machine_sprite)
    assert.are.equal("quoiging_red_hands", quoiging_chair.mod_overlay_type)

    local mock_doctor = {
      tile_x = 15,
      tile_y = 16,
    }
    local phase_action = { name = "multi_use_object", phase = -5, object = nil, use_with = mock_doctor }
    local patient_pos = { 0, 0 }
    local mock_patient = {
      th = {},
      tile_x = 15,
      tile_y = 15,
      getCurrentAction = function() return phase_action end,
      setPosition = function(_, x, y) patient_pos = { x, y } end,
    }
    local chair = setmetatable({
      th = {
        tick = function() end,
        setTile = function() end,
        setPosition = function() end,
        setHitTestResult = function() end,
        setPartialFlag = function() end,
        setAnimation = function() end,
      },
      object_type = quoiging_chair,
      direction = "north",
      tile_x = 15,
      tile_y = 15,
      world = {
        map = { th = { setCellFlags = function() end } },
        removeObjectFromTile = function() end,
        clearCaches = function() end,
      },
      user = false,
      getRenderAttachTile = Object.getRenderAttachTile,
    }, Machine._metatable)
    phase_action.object = chair

    -- When idle, custom Quoiging Chair draws under Layer 4 Entities and renders sprite 0
    assert.are.equal(DrawingLayers.NorthSideObject, chair:getDrawingLayer())
    chair:tick()
    assert.truthy(chair.mod_machine_sprite)
    assert.are.equal(ModSprites.QUOIGING_CHAIR_IDLE, chair.mod_machine_sprite.sprites[1].idx)

    -- Phase -5 (sitting down): Doctor wears spinning silly hat, chair stays idle until tickling begins
    chair.user = mock_patient
    chair:tick()
    assert.truthy(chair.mod_staff_overlay)
    assert.are.equal(mock_doctor.tile_x, chair.mod_staff_overlay.tile_x)
    assert.are.equal(mock_doctor.tile_y, chair.mod_staff_overlay.tile_y)
    assert.is_nil(chair.mod_overlay)

    -- Phase 0 (tickling): chair switches to active sprite 1, red hands + HA!/HEE! cycle 2..5, patient bounces
    phase_action.phase = 0
    local seen_tickle = {}
    local seen_hats = {}
    for _ = 1, 14 do
      chair:tick()
      assert.are.equal(ModSprites.QUOIGING_CHAIR_ACTIVE, chair.mod_machine_sprite.sprites[1].idx)
      assert.truthy(chair.mod_overlay)
      assert.truthy(chair.mod_staff_overlay)
      seen_tickle[chair.mod_overlay.sprites[1].idx] = true
      seen_hats[chair.mod_staff_overlay.sprites[1].idx] = true
    end
    assert.is_true(seen_tickle[2] and seen_tickle[3] and seen_tickle[4])
    assert.is_true(seen_hats[6] and seen_hats[7] and seen_hats[8])
    assert.is_true(patient_pos[1] ~= 0 or patient_pos[2] ~= 0)

    -- Completion clears red hands, silly hat, resets patient pos, and returns chair to idle sprite 0
    phase_action.phase = 2
    chair.user = false
    chair:tick()
    assert.is_nil(chair.mod_overlay)
    assert.is_nil(chair.mod_staff_overlay)
    assert.are.same({ 0, 0 }, patient_pos)
    assert.are.equal(ModSprites.QUOIGING_CHAIR_IDLE, chair.mod_machine_sprite.sprites[1].idx)

    -- Crashing hides custom chair sprite and restores entity layer for vanilla rubble
    chair.clearDynamicInfo = function() end
    chair.updateDynamicInfo = function() end
    chair:setCrashedAnimation()
    assert.is_nil(chair.mod_machine_sprite)
    assert.are.equal(DrawingLayers.Entity, chair:getDrawingLayer())
  end)

  it("renders custom Up-Down Gantry, grabs by the leg, turns patient upside down, and always cleans up", function()
    local dir = findModSpritesDir()
    local TH = require("TH")
    local orig_sheet = TH.sheet
    TheApp.getFullPath = function(_, folders)
      if folders[1] == "Bitmap" and folders[2] == "mod_sprites" then return dir end
      return ""
    end
    TheApp.gfx = setmetatable({
      app = TheApp,
      target = createMockSurface(),
      cache = { tabled = {}, raw = {}, palette = {}, anims = {}, ghosts = {}, language_fonts = {}, cursors = {} },
      reload_functions = {},
      reload_functions_last = {},
      load_info = {},
    }, Graphics._metatable)

    assert.is_true(up_down_rig.ticks)
    assert.are.equal("up_down_rig", up_down_rig.mod_machine_sprite)
    assert.are.equal("up_down_big_hands", up_down_rig.mod_overlay_type)

    local function makeMockPatient(hum_class)
      local p
      p = {
        humanoid_class = hum_class or "Standard Male Patient",
        tile_x = 20,
        tile_y = 20,
        pos = { 0, 0 },
        visible = true,
        th = {
          flags = 0,
          setPartialFlag = function(self, flag, enable)
            if enable == false then
              self.flags = flag_clear(self.flags, flag)
            else
              self.flags = flag_set(self.flags, flag)
            end
          end,
          makeInvisible = function(self)
            p.visible = false
            self.flags = flag_set(self.flags, DrawFlags.Alpha50 + DrawFlags.Alpha75)
          end,
          makeVisible = function(self)
            p.visible = true
            self.flags = flag_clear(self.flags, DrawFlags.Alpha50 + DrawFlags.Alpha75)
          end,
        },
        setPosition = function(self, x, y)
          self.pos = { x, y }
        end,
      }
      return setmetatable(p, Humanoid._metatable)
    end

    local patient = makeMockPatient("Standard Male Patient")
    local staff_action = { name = "multi_use_object", phase = -5, object = nil, use_with = patient }
    local mock_staff = {
      getCurrentAction = function() return staff_action end,
    }
    local rig = setmetatable({
      th = {
        tick = function() end,
        setTile = function() end,
        setPosition = function() end,
        setHitTestResult = function() end,
        setPartialFlag = function() end,
        setAnimation = function() end,
      },
      object_type = up_down_rig,
      direction = "north",
      tile_x = 19,
      tile_y = 20,
      world = {
        map = { th = { setCellFlags = function() end } },
        ui = {},
        entity_map = {
          addEntity = function() end,
          removeEntity = function() end,
        },
        entities = {},
        dispatcher = { dropFromQueue = function() end },
        removeObjectFromTile = function() end,
        getRoom = function() return nil end,
        clearCaches = function() end,
      },
      user = mock_staff,
      getRoom = function() return nil end,
      removeHandymanRepairTask = function() end,
      resetUsageAndReservaton = function() end,
      rebuildPassableCellFlags = function() end,
      getRenderAttachTile = Object.getRenderAttachTile,
    }, Machine._metatable)
    staff_action.object = rig

    -- Phase -5 (begin_use): custom rig switches active sprite 11, open ankle claw appears at ground
    rig:tick()
    assert.are.equal(ModSprites.UP_DOWN_RIG_ACTIVE, rig.mod_machine_sprite.sprites[1].idx)
    assert.are.equal(12, rig.mod_overlay.sprites[1].idx)
    assert.is_true(patient.visible)

    -- Phase 0, ticks 1..14 (fallback mode): lowers claw (12) -> clamps ankle (13) while patient upright
    staff_action.phase = 0
    for _ = 1, 10 do
      rig:tick()
    end
    assert.are.equal(13, rig.mod_overlay.sprites[1].idx)
    assert.is_true(patient.visible)
    assert.are.equal(-3, patient.pos[2])

    -- Ticks 15..30: hoisted & turned upside down by the leg (male dangle 14..17, upright sprite hidden cleanly)
    local seen_dangle = {}
    for _ = 11, 30 do
      rig:tick()
      if rig.mod_overlay then
        seen_dangle[rig.mod_overlay.sprites[1].idx] = true
      end
    end
    assert.is_true(seen_dangle[14] and seen_dangle[15])
    assert.is_false(patient.visible)
    assert.is_true(patient.up_down_inverted)
    assert.are.same({ 0, 0 }, staff_action.invisible_phase_span)
    assert.is_true(flag_isset(patient.permanent_flags or 0, DrawFlags.Alpha50 + DrawFlags.Alpha75))

    -- Ticks 31..48: lowering patient back down restores visibility and removes invisibility flags
    for _ = 31, 48 do
      rig:tick()
    end
    assert.is_true(patient.visible)
    assert.are.same({ 99, 100 }, staff_action.invisible_phase_span)
    assert.is_false(flag_isset(patient.permanent_flags or 0, DrawFlags.Alpha50 + DrawFlags.Alpha75))

    -- Verify UpDownRoom loop_callback keeps invisible_phase_span synced across grab -> dangle -> lower
    local UpDownRoomClassForLoop = _G["UpDownRoom"]
    local loop_staff_actions = {}
    local loop_staff = {
      setNextAction = function(_, act) loop_staff_actions[1] = act end,
      queueAction = function(_, act) loop_staff_actions[#loop_staff_actions + 1] = act end,
    }
    local loop_patient = makeMockPatient("Standard Male Patient")
    loop_patient.action_queue = {}
    loop_patient.setNextAction = function() end
    loop_patient.queueAction = function() end
    loop_patient.updateDynamicInfo = function() end
    local loop_room = setmetatable({
      staff_member = loop_staff,
      door = { queue = { visitor_count = 0 } },
      world = {
        findObjectNear = function() return rig, 19, 21 end,
      },
      _staffWaitToggle = function() end,
      dealtWithPatient = function() end,
    }, UpDownRoomClassForLoop._metatable)
    rig.getSecondaryUsageTile = function() return 20, 20 end
    loop_room:commandEnteringPatient(loop_patient)
    local loop_act = loop_staff_actions[2]
    assert.are.same({ 99, 100 }, loop_act.invisible_phase_span)
    for _ = 1, 13 do
      loop_act:loop_callback()
    end
    assert.are.same({ 99, 100 }, loop_act.invisible_phase_span)
    loop_act:loop_callback() -- tick 14 -> enters dangle window
    assert.are.same({ 0, 0 }, loop_act.invisible_phase_span)
    for _ = 15, 45 do
      loop_act:loop_callback()
    end
    assert.are.same({ 0, 0 }, loop_act.invisible_phase_span)
    loop_act:loop_callback() -- tick 46 -> lowers patient upright
    assert.are.same({ 99, 100 }, loop_act.invisible_phase_span)

    -- Verify female patient selects female dangle set (18..21) and stays hidden while dangling
    local fpatient = makeMockPatient("Standard Female Patient")
    staff_action.use_with = fpatient
    rig.mod_overlay_phase = nil
    for _ = 1, 22 do
      rig:tick()
    end
    assert.is_true(rig.mod_overlay.sprites[1].idx >= 18 and rig.mod_overlay.sprites[1].idx <= 21)
    assert.is_false(fpatient.visible)
    assert.are.same({ 0, 0 }, staff_action.invisible_phase_span)

    -- Verify native PNG + C++ vertical flip branch uses live flipped patient + ankle claw 22/23
    TH.sheet = function()
      return { loadPNGs = function() return true end }
    end
    TheApp.gfx.cache.tabled = {}
    TheApp.gfx.has_native_mod_pngs = nil
    staff_action.use_with = patient
    rig.mod_overlay_phase = nil
    for _ = 1, 18 do
      rig:tick()
    end
    assert.is_true(TheApp.gfx.has_native_mod_pngs)
    assert.is_true(patient.visible)
    assert.is_true(flag_isset(patient.th.flags, DrawFlags.FlipVertical))
    assert.is_true(patient.pos[2] < -70)
    assert.is_true(rig.mod_overlay.sprites[1].idx == 22 or rig.mod_overlay.sprites[1].idx == 23)

    -- Save/load check: Machine:afterLoad detaches overlays and re-syncs custom base machine sprite
    local old_overlay = rig.mod_overlay
    local old_base = rig.mod_machine_sprite
    rig.clearDynamicInfo = function() end
    rig.updateDynamicInfo = function() end
    rig:afterLoad(256, 256)
    assert.is_true(old_overlay.detached)
    assert.is_true(old_base.detached)
    assert.truthy(rig.mod_machine_sprite)

    -- Room leave & edit/destroy paths ALWAYS restore visibility, flags, and position
    local UpDownRoomClass = _G["UpDownRoom"]
    local mock_room = setmetatable({
      is_active = true,
      room_info = { id = "up_down_room" },
      inverted_patient = patient,
      staff_member = mock_staff,
      objects = { [rig] = true },
      humanoids = { [patient] = true },
      world = {
        notifyRoomRemoved = function() end,
        dispatcher = { callForStaff = function() end },
      },
      door = {
        queue = {
          rerouteAllPatients = function() end,
          patientSize = function() return 0 end,
          reportedSize = function() return 0 end,
          size = function() return 0 end,
        },
        updateDynamicInfo = function() end,
      },
      hospital = { removeRatholesAroundRoom = function() end },
    }, UpDownRoomClass._metatable)

    mock_room:onHumanoidLeave(patient)
    assert.is_true(patient.visible)
    assert.is_false(flag_isset(patient.th.flags, DrawFlags.FlipVertical))
    assert.are.same({ 0, 0 }, patient.pos)
    assert.is_nil(mock_room.inverted_patient)

    -- Test destroy cleanup via Machine:onDestroy
    TH.sheet = orig_sheet
    rig:onDestroy()
    assert.is_nil(rig.mod_overlay)
    assert.is_nil(rig.mod_machine_sprite)
  end)
end)
