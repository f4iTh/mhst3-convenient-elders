-- local stageManager = sdk.find_type_definition("app.StageManager")
-- local currentStage = stageManager:get_field("<CurrentStageData>k__BackingField")
-- local currentStageID = currentStage:get_field("<ID>k__BackingField")
-- local setElder = stageManager:get_method("set_ElderID(app.EnemyDef.ID)")

-- app.FieldElderController.lottery()
-- called by: app.cGameStateBattle.lotteryElder()

-- app.FieldElderController.battleJudgElderPopEnd(app.cEnemyContext)
-- called by: app.cGameStateBattle.lotteryElder()

-- app.cGameStateBattle.lotteryElder()
-- called by: app.cGameStateBattle.isCompletedLeave()

-- TODO: force elder spawns depending on the current stage/location/area (i.e., night battles in azuria should guarantee namielle)
-- TODO: clean up field (re)setting; a bit too messy right now

local logMsgStart = "[Convenient Elders] "

local initialized = false

local config_path = "convenient_elders_config.json"

local defaults = {
  elderBasePopRate = 10,
  elderEndBattleCount = 5,
  overrideByLocation = true
}

local config = {
  enabled = true,           -- Whether mod (features) should be enabled
  elderBasePopRate = 10,    -- The base appearance rate of a calamitous elder dragon as percentage (0 - 100, default: 10)
  elderEndBattleCount = 5,  -- How many battles until calamitous elder goes away (default: 5)
  overrideByLocation = true -- Force elder spawns depending on the current stage/location/area (i.e., battles in Azuria should guarantee Namielle)
}

-- TODO: elder dragon em_ids
-- local eldersByStageID = {
--   [1769129856] = 0, -- Azuria / Namielle
--   [884165440]  = 1, -- Canalta Timberland / Ibushi & Narwa
--   [1834912896] = 2, -- Tarkuan / Yama Tsukami
--   [1491992832] = 3  -- Serathis / Velkhana
-- }

--- Valid stage IDs for where calamitous elders can spawn;
--- Could probably also check with `app.cSaveDataHelper_Field.isOpenMap(app.StageDef.StageID_Fixed)`
local validStageIDs = {
  1769129856, -- Azuria
  884165440,  -- Canalta Timberland
  1834912896, -- Tarkuan
  1491992832  -- Serathis
}

local stageIDNone = 4117922480 -- If no elders, set it to this value (-177044816 if properly converted)

local stageManager = nil
local fieldElderController = nil
local fieldElderUserData = nil

-- local fieldSaveDataHelper = nil
-- local stageDef = nil

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
    log.error(logMsgStart .. "could not find 'app.StageManager._FieldElderCtrl._FieldElderParamUserData'")
    return
  end

  fieldElderUserData:set_field("BasePopRate", config.elderBasePopRate)
  fieldElderUserData:set_field("ElderEndBattleCount", config.elderEndBattleCount)

  initialized = true
end

--- Reset config (and game) values back to default
local function resetDefaults()
  if not fieldElderUserData then
    log.error(logMsgStart .. "'app.StageManager._FieldElderCtrl._FieldElderParamUserData' is nil; cannot reset values")
    return
  end

  fieldElderUserData:set_field("BasePopRate", defaults.elderBasePopRate)
  fieldElderUserData:set_field("ElderEndBattleCount", defaults.elderEndBattleCount)

  config.elderBasePopRate = defaults.elderBasePopRate
  config.elderEndBattleCount = defaults.elderEndBattleCount
  config.overrideByLocation = defaults.overrideByLocation
end

-- local function to_int32(num)
--   if num < 0 then
--     num = num + (2147483648)
--   end
--   return num
-- end

-- local function from_int32(num)
--   if num > 2147483648 then
--     num = num - (2 * 2147483648)
--     return num
--   else
--     return num
--   end
-- end

-- mod init hook
sdk.hook(
  sdk.find_type_definition("app.SaveDataManager"):get_method("getTitleText()"),
  function(args)
    if not initialized then
      init()
    end
  end,
  function(retval)
    return retval
  end
)

-- very dumb elder spawn override hook
-- sdk.hook(
--   sdk.find_type_definition("System.Collections.Generic.List`1<app.StageDef.StageID_Fixed>"):get_method("AddWithResize(app.StageDef.StageID_Fixed)"),
--   function(args)
--     local obj = sdk.to_managed_object(args[2])
--     if obj:get_field("Elder_Pop_StageId_Array") then
--       -- ensure stageManager exists
--       if not stageManager then
--         return sdk.PreHookResult.CALL_ORIGINAL
--       end
--       -- get current stage id
--       local currentStage = stageManager:get_field("<CurrentStageData>k__BackingField")
--       if not currentStage then
--         return sdk.PreHookResult.CALL_ORIGINAL
--       end
--       -- overwrite stage id param if valid
--       local currentStageId = currentStage:get_field("<ID>k__BackingField")
--       if has_value(validStageIDs, currentStageId) then
--         args[3] = currentStage:get_field("<ID>k__BackingField")
--       end
--     end
--     return sdk.PreHookResult.CALL_ORIGINAL
--   end,
--   function(retval)
--     return retval
--   end
-- )

-- ---Converts unsigned 32-bit into signed 32-bit integer. Value should be an actual 32-bit (un)signed integer, otherwise the result WILL be wrong
-- ---@param num number
-- ---@return number
-- local function to_int32(num)
--   if num > 2147483648 then
--     num = num - (2 * 2147483648)
--     return num
--   else
--     return num
--   end
-- end

-- elder spawn override hook
sdk.hook(
  sdk.find_type_definition("app.cSaveDataHelper_Field"):get_method("setPopElderStageId(app.StageDef.StageID_Fixed)"),
  function(args)
    -- log.debug("StageID_Fixed: " .. tostring(to_int32(sdk.to_int64(args[3]))))
    log.debug("StageID_Fixed: " .. tostring(sdk.to_int64(args[3])))

    -- skip if not enabled
    if not config.enabled then
      return sdk.PreHookResult.CALL_ORIGINAL
    end

    if not config.overrideByLocation then
      return sdk.PreHookResult.CALL_ORIGINAL
    end

    -- skip early if the elder should despawn
    if sdk.to_int64(args[3]) == stageIDNone then
      return sdk.PreHookResult.CALL_ORIGINAL
    end

    -- ensure stageManager exists
    -- local stageManager = sdk.get_managed_singleton("app.StageManager")
    if not stageManager then
      return sdk.PreHookResult.CALL_ORIGINAL
    end

    -- get current stage id
    -- local currentStage = stageManager:get_field("<CurrentStageData>k__BackingField")
    local currentStage = stageManager:call("get_CurrentStageData()")
    if not currentStage then
      return sdk.PreHookResult.CALL_ORIGINAL
    end

    -- local currentStageId = currentStage:get_field("<ID>k__BackingField")
    local currentStageId = currentStage:call("get_ID()")
    if not currentStageId then
      return sdk.PreHookResult.CALL_ORIGINAL
    end

    -- overwrite stage id param if valid
    if has_value(validStageIDs, currentStageId) then
      log.debug("overriding StageID_Fixed to: " .. tostring(currentStageId))
      args[3] = sdk.to_ptr(currentStageId)
    end

    log.debug("new StageID_Fixed: " .. sdk.to_int64(args[3]))

    return sdk.PreHookResult.CALL_ORIGINAL
  end,
  function(retval)
    -- log.debug("setPopElderStageId(app.StageDef.StageID_Fixed) retval: " .. sdk.to_managed_object(retval))
    log.debug("setPopElderStageId(app.StageDef.StageID_Fixed) retval: " .. sdk.to_int64(retval))
    return retval
  end
)

-- temp hook for checking how `isOpenMap` functions
-- sdk.hook(
--   sdk.find_type_definition("app.cSaveDataHelper_Field"):get_method("isOpenMap(app.StageDef.StageID_Fixed)"),
--   function(args)
--     log.debug("isOpenMap(app.StageDef.StageID_Fixed): " .. tostring(sdk.to_int64(args[3])))
--     return sdk.PreHookResult.CALL_ORIGINAL
--   end,
--   function(retval)
--     local retvalBool = (sdk.to_int64(retval) & 1) == 1
--     log.debug("isOpenMap(app.StageDef.StageID_Fixed): " .. tostring(retvalBool))
--     return retval
--   end
-- )

-- init if resetting scripts (i.e., during development)
if not initialized then
  init()
end

re.on_draw_ui(function()
  if imgui.tree_node("Convenient Elders") then
    local changed, newEnabled = imgui.checkbox("Enable mod?", config.enabled)
    if changed then
      config.enabled = newEnabled
      if not config.enabled then -- reset defaults if disabled
        resetDefaults()
      else
        if fieldElderUserData then
          fieldElderUserData:set_field("BasePopRate", config.elderBasePopRate)
          fieldElderUserData:set_field("ElderEndBattleCount", config.elderEndBattleCount)
        end
      end
      save_config()
    end

    if config.enabled then
      ---@diagnostic disable-next-line: missing-parameter, redefined-local
      local changed, newElderBasePopRate = imgui.slider_int("Base calamitous elder spawn rate", config.elderBasePopRate, 0, 100)
      if changed then
        config.elderBasePopRate = newElderBasePopRate
        if fieldElderUserData then
          fieldElderUserData:set_field("BasePopRate", config.elderBasePopRate)
        end
        save_config()
      end

      ---@diagnostic disable-next-line: missing-parameter, redefined-local
      local changed, newElderEndBattleCount = imgui.slider_int("Elder end battle count", config.elderEndBattleCount, 1, 10)
      if changed then
        config.elderEndBattleCount = newElderEndBattleCount
        if fieldElderUserData then
          fieldElderUserData:set_field("ElderEndBattleCount", config.elderEndBattleCount)
        end
        save_config()
      end

      ---@diagnostic disable-next-line: redefined-local
      local changed, newOverrideByLocation = imgui.checkbox("Override elder spawn by location?", config.overrideByLocation)
      if changed then
        config.overrideByLocation = newOverrideByLocation
        save_config()
      end

      imgui.separator()
      if imgui.button("Reset to defaults?") then
        resetDefaults()
      end
    end

    -- temporary debug stuff
    imgui.separator()
    imgui.text("DEBUG")
    if imgui.button("get_IsCurrentStageElderPop()") then
      log.debug("get_IsCurrentStageElderPop(): " .. tostring(stageManager:call("get_IsCurrentStageElderPop()")))
    end
    if imgui.button("get_IsCurrentStageElderWeather()") then
      log.debug("get_IsCurrentStageElderWeather(): " .. tostring(stageManager:call("get_IsCurrentStageElderWeather()")))
    end
    if imgui.button("get_ElderID()") then
      log.debug("get_ElderID(): " .. tostring(stageManager:call("get_ElderID()")))
    end

    imgui.text("Current stage id: " .. tostring(stageManager:get_field("<CurrentStageData>k__BackingField"):get_field("<ID>k__BackingField")))
    -- if imgui.button("isOpenMap(app.StageDef.StageID_Fixed)") then
    --   local saveDataHelperField = sdk.find_type_definition("app.cSaveDataHelper_Field")
    --   -- local isOpenMapMethod = saveDataHelperField:get_method("isOpenMap(app.StageDef.StageID_Fixed)")
    --   local currentStage = stageManager:get_field("<CurrentStageData>k__BackingField")
    --   local currentStageId = currentStage:get_field("<ID>k__BackingField")
    --   log.debug("isOpenMap(app.StageDef.StageID_Fixed): " .. tostring(saveDataHelperField:call("isOpenMap(app.StageDef.StageID_Fixed)", currentStageId)))
    -- end

    imgui.tree_pop()
  end
end)
