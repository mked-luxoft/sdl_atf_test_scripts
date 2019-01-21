---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: The attempt to open the protected Video, Audio, RPC services with unsuccessful
-- OnStatusUpdate(REQUEST_REJECTED, INVALID_TIME) notification by receiving GetSystemTime response with invalid result
-- code from HMI and services are force protected
-- Precondition:
-- 1) App is registered with NAVIGATION appHMIType and activated.
-- In case:
-- 1) Mobile app requests StartService (Video encryption = true)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (VIDEO, REQUEST_RECEIVED) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- In case: HMI send GetSystemTime_Rq(Time is not provided) to SDL
-- SDL does:
-- 1) send StartServiceNACK(Video) to mobile app
-- 2) send OnServiceUpdate (VIDEO, INVALID_TIME, REQUEST_REJECTED) to HMI
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ServiceStatusUpdateToHMI/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

-- [[ Local function ]]
function common.getSystemTimeRes(pData)
  common.getHMIConnection():SendError(pData.id, pData.method, "WRONG_ENUM", "Time is not provided")
end

function common.onServiceUpdateFunc(pServiceTypeValue)
  common.serviceStatusWithGetSystemTimeUnsuccess(pServiceTypeValue)
end

function common.serviceResponseFunc(pServiceId)
  common.getMobileSession():ExpectControlMessage(pServiceId, {
    frameInfo = common.frameInfo.START_SERVICE_NACK,
    encryption = false
  })
  :Timeout(11000)
end

common.policyTableUpdateFunc = function() end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions, { "0x0B, 0x0A" })
runner.Step("Init SDL certificates", common.initSDLCertificates,
  { "./files/Security/client_credential_expired.pem", false })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App registration", common.registerApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate)
runner.Step("App activation", common.activateApp)

runner.Title("Test")
runner.Step("Start Video Service protected with invalid response to GetSystemTime request",
  common.startServiceWithOnServiceUpdate, { 11, 0 })
runner.Step("Start Audio Service protected with invalid response to request",
  common.startServiceWithOnServiceUpdate, { 10, 0 })
runner.Step("Start RPC Service protected with invalid response to GetSystemTime request",
  common.startServiceWithOnServiceUpdate, { 7, 0 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
