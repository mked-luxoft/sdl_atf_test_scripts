---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0119-SDL-passenger-mode.md
-- Description:
-- In case:
-- 1) OnDriverDistraction notification is  allowed by Policy for (FULL, LIMITED, BACKGROUND) HMILevel
-- 2) In Policy "lock_screen_dismissal_enabled" parameter is defined with "true" value
-- 3) App registered (HMI level NONE)
-- 4) HMI sends OnDriverDistraction notification with all mandatory fields (state = "DD_OFF")
-- 5) App activated (HMI level FULL)
-- 6) HMI sends OnDriverDistraction notification with all mandatory fields
-- SDL does:
-- 1) Not send  OnDriverDistraction notification to mobile when HMI level is NONE
-- 2) Send OnDriverDistraction notification without "lockScreenDismissalEnabled" to mobile once app is activated
-- 3) Send OnDriverDistraction notification to mobile without "lockScreenDismissalEnabled" once HMI sends it to SDL
-- when app is in FULL
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/SDL_Passenger_Mode/commonPassengerMode')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local lockScreenDismissalEnabled = true

--[[ Local Functions ]]
local function updatePreloadedPT()
  local function updatePT(pPT)
    pPT.policy_table.functional_groupings["Base-4"].rpcs.OnDriverDistraction.hmi_levels = { "FULL" }
  end
  common.updatePreloadedPT(lockScreenDismissalEnabled, updatePT)
end

local function registerApp()
  common.registerAppWOPTU()
  common.getMobileSession():ExpectNotification("OnDriverDistraction")
  :Times(0)
end

local function onDriverDistractionUnsuccess()
  common.getHMIConnection():SendNotification("UI.OnDriverDistraction", { state = "DD_OFF" })
  common.getMobileSession():ExpectNotification("OnDriverDistraction")
  :Times(0)
end

local function activateApp()
  common.activateApp()
  common.getMobileSession():ExpectNotification("OnDriverDistraction",
    { state = "DD_OFF" })
end

local function OnDriverDistractionOFF()
  local function msg(pValue)
    return "Parameter `lockScreenDismissalEnabled` is transfered to Mobile with `" .. tostring(pValue) .. "` value"
  end
  common.getHMIConnection():SendNotification("UI.OnDriverDistraction", { state = "DD_OFF" })
  common.getMobileSession():ExpectNotification("OnDriverDistraction",{ state = "DD_OFF" })
  :ValidIf(function(_, d)
      if d.payload.lockScreenDismissalEnabled ~= nil then
        return false, d.payload.state .. ": " .. msg(d.payload.lockScreenDismissalEnabled)
      end
      return true
    end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Set LockScreenDismissalEnabled", updatePreloadedPT, { lockScreenDismissalEnabled })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App registration HMI level NONE", registerApp)

runner.Title("Test")
runner.Step("OnDriverDistraction OFF not transfered", onDriverDistractionUnsuccess)
runner.Step("App activation HMI level FULL", activateApp)
runner.Step("OnDriverDistraction OFF missing", OnDriverDistractionOFF)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
