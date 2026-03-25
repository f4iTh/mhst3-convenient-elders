-- TODO: clean up field (re)setting; a bit too messy right now

local logMsgStart = "[Convenient Elders] "

local initialized = false
local config_path = "convenient_elders_config.json"

local defaults = {
  elderBaseSpawnChance = 10,
  elderDespawnBattleCount = 5,
  forceSameAreaElder = true
}

local config = {
  modEnabled = true,           -- Whether mod (features) should be enabled
  elderBaseSpawnChance = 10,   -- The base appearance rate of a calamitous elder dragon as percentage (0 - 100, default: 10)
  elderDespawnBattleCount = 5, -- How many battles until calamitous elder goes away (default: 5)
  forceSameAreaElder = true    -- Force elder spawns depending on the current stage/location/area (i.e., battles in Azuria should guarantee Namielle)
}

--- Valid stage IDs for where calamitous elders can spawn;
--- Could probably also check with `app.cSaveDataHelper_Field.isOpenMap(app.StageDef.StageID_Fixed)`
local validStageIDs = {
  1769129856, -- Azuria
  884165440,  -- Canalta Timberland
  1834912896, -- Tarkuan
  1491992832  -- Serathis
}

local stageIDNone = 4117922480 -- If no elders, set it to this value (app.StageDef.StageID_Fixed.None / -177044816 if properly converted to int32)

local stageManager = nil
local fieldElderController = nil
local fieldElderUserData = nil

--- Sets config values if they exist, otherwise uses default values
local function load_config()
  local c = json.load_file(config_path)
  if c ~= nil then
    config = c
  end
end

--- Saves current config
local function save_config()
  json.dump_file(config_path, config)
end

---Handle mod enable/disable toggle
---@param enabled boolean
local function handleModEnableToggle(enabled)
  if not fieldElderUserData then
    log.error(logMsgStart .. "'app.StageManager._FieldElderCtrl._FieldElderParamUserData' is null; cannot set field values")
    return
  end

  if not enabled then
    fieldElderUserData:set_field("BasePopRate", defaults.elderBaseSpawnChance)
    fieldElderUserData:set_field("ElderEndBattleCount", defaults.elderDespawnBattleCount)
  else
    fieldElderUserData:set_field("BasePopRate", config.elderBaseSpawnChance)
    fieldElderUserData:set_field("ElderEndBattleCount", config.elderDespawnBattleCount)
  end
end

--- Checks a table if specified value exists
---@param t table
---@param val string|number
local function has_value(t, val)
  for index, value in ipairs(t) do
    if value == val then
      return true
    end
  end

  return false
end

--- Initialize singletons, config values, etc.
local function init()
  if initialized then
    return
  end

  load_config()

  stageManager = sdk.get_managed_singleton("app.StageManager")
  if not stageManager then
    log.error(logMsgStart .. "could not find 'app.StageManager'")
    return
  end

  fieldElderController = stageManager:get_field("_FieldElderCtrl")
  if not fieldElderController then
    log.error(logMsgStart .. "could not find 'app.StageManager._FieldElderCtrl'")
    return
  end

  fieldElderUserData = fieldElderController:get_field("_FieldElderParamUserData")
  if not fieldElderUserData then
    log.error(logMsgStart .. "'could not find 'app.StageManager._FieldElderCtrl.'_FieldElderParamUserData'")
    return
  end

  fieldElderUserData:set_field("BasePopRate", config.elderBaseSpawnChance)
  fieldElderUserData:set_field("ElderEndBattleCount", config.elderDespawnBattleCount)

  initialized = true
end

---Adds a convenient tooltip before the actual menu entry
---@param msg string
local function pre_tooltip(msg)
  if msg == nil then
    msg = "(no tooltip)"
  end

  imgui.text("(?)")
  ---@diagnostic disable-next-line: missing-parameter
  if imgui.is_item_hovered() then
    imgui.set_tooltip("\n" .. msg .. "\n ")
    -- imgui.set_tooltip(msg)
  end
  imgui.same_line()
end

-- Mod init hook
sdk.hook(
  sdk.find_type_definition("app.SaveDataManager"):get_method("getTitleText()"),
  function(args)
    init()
  end,
  function(retval)
    return retval
  end
)

-- Elder spawn override hook
sdk.hook(
  sdk.find_type_definition("app.cSaveDataHelper_Field"):get_method("setPopElderStageId(app.StageDef.StageID_Fixed)"),
  function(args)
    log.debug(logMsgStart .. "StageID_Fixed: " .. tostring(sdk.to_int64(args[3])))

    if not config.modEnabled or not config.forceSameAreaElder then
      return sdk.PreHookResult.CALL_ORIGINAL
    end

    -- skip early if the elder should despawn
    if sdk.to_int64(args[3]) == stageIDNone then
      return sdk.PreHookResult.CALL_ORIGINAL
    end

    if not stageManager then
      return sdk.PreHookResult.CALL_ORIGINAL
    end

    -- get current stage id
    local currentStage = stageManager:call("get_CurrentStageData()")
    if not currentStage then
      return sdk.PreHookResult.CALL_ORIGINAL
    end

    local currentStageId = currentStage:call("get_ID()")
    if not currentStageId then
      return sdk.PreHookResult.CALL_ORIGINAL
    end

    -- overwrite stage id param if valid
    if has_value(validStageIDs, currentStageId) then
      log.debug(logMsgStart .. "overriding StageID_Fixed to: " .. tostring(currentStageId))
      args[3] = sdk.to_ptr(currentStageId)
    end

    log.debug(logMsgStart .. "new StageID_Fixed: " .. sdk.to_int64(args[3]))

    return sdk.PreHookResult.CALL_ORIGINAL
  end,
  function(retval)
    -- log.debug(logMsgStart .. "setPopElderStageId(app.StageDef.StageID_Fixed) retval: " .. sdk.to_int64(retval))
    return retval
  end
)

-- init if resetting scripts (i.e., during development)
if not initialized then
  init()
end

re.on_draw_ui(function()
  if imgui.tree_node("Convenient Elders") then
    local modEnabledChanged, newModEnabled = imgui.checkbox("Enable mod?", config.modEnabled)
    if modEnabledChanged then
      config.modEnabled = newModEnabled
      handleModEnableToggle(newModEnabled)
      save_config()
    end

    if config.modEnabled then
      pre_tooltip("Base chance of a calamitous elder appearing / spawning (n %%); 50 meaning 50 %%\nDefault: 10 (%%)")
      ---@diagnostic disable-next-line: missing-parameter
      local elderBasePopRateChanged, newElderBasePopRate = imgui.slider_int("Base spawn rate (n %)", config.elderBaseSpawnChance, 0, 100)
      if elderBasePopRateChanged then
        config.elderBaseSpawnChance = newElderBasePopRate
        if fieldElderUserData then
          fieldElderUserData:set_field("BasePopRate", config.elderBaseSpawnChance)
        end
        save_config()
      end

      pre_tooltip("How many battles to require until the calamitous elder despawns / retreats\nDefault: 5")
      ---@diagnostic disable-next-line: missing-parameter
      local elderEndBattleCountChanged, newElderEndBattleCount = imgui.slider_int("Battle retreat count", config.elderDespawnBattleCount, 1, 10)
      if elderEndBattleCountChanged then
        config.elderDespawnBattleCount = newElderEndBattleCount
        if fieldElderUserData then
          fieldElderUserData:set_field("ElderEndBattleCount", config.elderDespawnBattleCount)
        end
        save_config()
      end

      pre_tooltip("Forces the calamitous elder of the current area to spawn (i.e., Azuria elder in Azuria)")
      local overrideByLocationChanged, newOverrideByLocation = imgui.checkbox("Force same area elder?", config.forceSameAreaElder)
      if overrideByLocationChanged then
        config.forceSameAreaElder = newOverrideByLocation
        save_config()
      end
    end

    imgui.tree_pop()
  end
end)
