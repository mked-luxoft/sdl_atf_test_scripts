---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: The attempt to open the protected Video, Audio, RPC services with unsuccessful
--  OnStatusUpdate(REQUEST_REJECTED, INVALID_TIME) notification by receiving GetSystemTime response with invalid result
--  code from HMI and services are not force protected
-- Precondition:
-- 1) App is registered with NAVIGATION appHMIType and activated.
-- In case:
-- 1) Mobile app requests StartService (Video encryption = false)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (VIDEO, REQUEST_RECEIVED) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- In case: HMI send GetSystemTime_Rq(provided not correct time) to SDL
-- SDL does:
-- 1) send StartServiceACK(Video) to mobile app
-- 2) send OnServiceUpdate (VIDEO, INVALID_TIME, REQUEST_REJECTED) to HMI
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ServiceStatusUpdateToHMI/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Function ]]
function common.getSystemTimeRes(pData)
  common.getHMIConnection():SendError(pData.id, pData.method, "WRONG_ENUM", "Time is not provided")
end

function common.onServiceUpdateFunc(pServiceTypeValue)
  common.serviceStatusWithGetSystemTimeUnsuccess(pServiceTypeValue)
end

function common.serviceResponseFunc(pServiceId, pStreamingFunc)
  common.serviceResponseWithACKandNACK(pServiceId, pStreamingFunc, 11000)
end

common.policyTableUpdateFunc = function() end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App registration", common.registerApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate)
runner.Step("App activation", common.activateApp)

runner.Title("Test")
runner.Step("Start Video Service protected with invalid response to GetSystemTime request",
  common.startServiceWithOnServiceUpdate, { 11, 0 })
runner.Step("Start Audio Service protected with invalid response to GetSystemTime request",
  common.startServiceWithOnServiceUpdate, { 10, 0 })
runner.Step("Start RPC Service protected with invalid response to GetSystemTime request",
  common.startServiceWithOnServiceUpdate, { 7, 0 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
