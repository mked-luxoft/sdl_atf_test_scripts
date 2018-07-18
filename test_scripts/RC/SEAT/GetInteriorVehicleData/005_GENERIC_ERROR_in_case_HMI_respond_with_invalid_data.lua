---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0105-remote-control-seat.md
-- User story:
-- Use case:
-- Item:
--
-- Description:
-- In case:
-- 1) RC app sends GetInteriorVehicleData request with valid parameters
-- 2) and HMI responds with invalid data:
--    - invalid type of parameter
--    - missing mandatory parameter
-- SDL must:
-- 1) Respond to App with success:false, "GENERIC_ERROR"
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/SEAT/commonRC')
local initialCommon = require('test_scripts/RC/commonRC')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
local function invalidParamType(pModuleType)
  local mobSession = commonRC.getMobileSession()
  local cid = mobSession:SendRPC("GetInteriorVehicleData", {
    moduleType = pModuleType,
    subscribe = true
  })

  EXPECT_HMICALL("RC.GetInteriorVehicleData", {
    moduleType = pModuleType,
    subscribe = true
  })
  :Do(function(_, data)
      commonRC.getHMIconnection():SendResponse(data.id, data.method, "SUCCESS", {
        moduleData = initialCommon.getModuleControlData(pModuleType),
        isSubscribed = "yes" -- invalid type of parameter
      })
    end)

  mobSession:ExpectResponse(cid, { success = false, resultCode = "GENERIC_ERROR" })
end

local function missingMandatoryParam(pModuleType)
  local mobSession = commonRC.getMobileSession()
  local cid = mobSession:SendRPC("GetInteriorVehicleData", {
    moduleType = pModuleType,
    subscribe = true
  })

  EXPECT_HMICALL("RC.GetInteriorVehicleData", {
    moduleType = pModuleType,
    subscribe = true
  })

  :Do(function(_, data)
      local moduleData = initialCommon.getModuleControlData(pModuleType)
      moduleData.moduleType = nil -- missing mandatory parameter
      commonRC.getHMIconnection():SendResponse(data.id, data.method, "SUCCESS", {
        moduleData = moduleData,
        isSubscribed = true
      })
    end)

  mobSession:ExpectResponse(cid, { success = false, resultCode = "GENERIC_ERROR" })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI, PTU", commonRC.rai_ptu)
runner.Step("Activate App", commonRC.activate_app)

runner.Title("Test")
runner.Step("GetInteriorVehicleData SEAT Invalid response from HMI-Invalid type of parameter", invalidParamType,
  { "SEAT" })
runner.Step("GetInteriorVehicleData SEAT Invalid response from HMI-Missing mandatory parameter", missingMandatoryParam,
  { "SEAT" })

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
