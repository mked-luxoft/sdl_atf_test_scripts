---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0240-sdl-js-pwa.md
--
-- Description:
-- Processing of the UpdateAppList request to HMI if Web application is unregistered
--
-- Precondition:
-- 1. SDL and HMI are started
-- 2. Web app is enabled through SetAppProperties
-- 3. Web app is registered and activated

-- Sequence:
-- 1. Web app is unregistered
--  a. SDL does send BC.UpdateAppList with Web app since it is still enabled
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/WebEngine/commonWebEngine')

--[[ Local Variables ]]
local appData

--[[ Local Functions ]]
local function setAppProperties()
  local appProp = {
    nicknames = { "Test Application" },
    policyAppID = "0000001",
    enabled = true,
    authToken = "ABCD12345",
    transportType = "WS",
    hybridAppPreference = "CLOUD"
  }
  common.getHMIConnection():ExpectRequest("BasicCommunication.UpdateAppList")
  :ValidIf(function(_, data)
      if #data.params.applications == 0 then
        return false, "BC.UpdateAppList is empty"
      else
        appData = data.params.applications[1]
        appData.appID = nil
      end
      return true
    end)
  common.setAppProperties(appProp)
end

local function unRegisterApp()
  common.getHMIConnection():ExpectRequest("BasicCommunication.UpdateAppList", { applications = { appData }})
  common.unRegisterApp()
end

-- [[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Start SDL, HMI, connect regular mobile, start Session", common.start)

common.Title("Test")
common.Step("SetAppProperties enabled=true", setAppProperties)
common.Step("Register App", common.registerAppWOPTU)
common.Step("Activate App", common.activateApp)
common.Step("Unregister App", unRegisterApp)

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
