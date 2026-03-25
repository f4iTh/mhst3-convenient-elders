-- OLD FUNCTIONAL VERSION

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

local defaults = {
  elderBasePopRate = 10,
  elderEndBattleCount = 5
}

local hasInit = false

local config = {
  enabled = true,
  elderBasePopRate = 10,  -- the base appearance rate of a calamitous elder dragon as percentage (0 - 100, default: 10)
  elderEndBattleCount = 5 -- how many battles until calamitous elder goes away (default: 5)
}

local config_path = "convenient_elders_config.json"

-- TODO: elder dragon em_ids
local eldersByStageID = {
  [1769129856] = 0, -- Azuria / Namielle
  [884165440]  = 1, -- Canalta Timberland / Ibushi & Narwa
  [1834912896] = 2, -- Tarkuan / Yama Tsukami
  [1491992832] = 3  -- Serathis / Velkhana
}

local stageManager = nil
local fieldElderController = nil
local fieldElderUserData = nil

local fieldSaveDataHelper = nil

local function load_config()
  local c = json.load_file(config_path)
  if c ~= nil then
    config = c
  end
end

local function save_config()
  json.dump_file(config_path, config)
end

local function init()
  load_config()

  fieldSaveDataHelper = sdk.find_type_definition("app.cSaveDataHelper_Field")
  if not fieldSaveDataHelper then
    log.error(logMsgStart .. "could not find 'app.cSaveDataHelper_Field'")
  end

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

  hasInit = true
end

local function resetDefaults()
  if not fieldElderUserData then
    log.error(logMsgStart .. "'app.StageManager._FieldElderCtrl._FieldElderParamUserData' is nil; cannot reset values")
    return
  end

  fieldElderUserData:set_field("BasePopRate", defaults.elderBasePopRate)
  fieldElderUserData:set_field("ElderEndBattleCount", defaults.elderEndBattleCount)
end

sdk.hook(
  sdk.find_type_definition("app.SaveDataManager"):get_method("getTitleText()"),
  function(args)
    if not hasInit then
      init()
    end
  end,
  function(retval)
    return retval
  end
)

if not hasInit then
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
        fieldElderUserData:set_field("BasePopRate", config.elderBasePopRate)
        fieldElderUserData:set_field("ElderEndBattleCount", config.elderEndBattleCount)
      end
      save_config()
    end

    if config.enabled then
      local changed, newElderBasePopRate = imgui.slider_int("Base calamitous elder spawn rate", config.elderBasePopRate, 0, 100)
      if changed then
        config.elderBasePopRate = newElderBasePopRate
        fieldElderUserData:set_field("BasePopRate", config.elderBasePopRate)
        save_config()
      end

      local changed, newElderEndBattleCount = imgui.slider_int("Elder end battle count", config.elderEndBattleCount, 1, 10)
      if changed then
        config.elderEndBattleCount = newElderEndBattleCount
        fieldElderUserData:set_field("ElderEndBattleCount", config.elderEndBattleCount)
        save_config()
      end

      if imgui.button("Reset to defaults?") then
        resetDefaults()
      end
    end

    imgui.tree_pop()
  end
end)
