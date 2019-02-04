---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: The attempt to open the protected RPC service with unsuccessful OnStatusUpdate(REQUEST_REJECTED,
-- PTU_FAILED) notification by unsuccessful PTU
-- Precondition:
-- 1) App is registered with NAVIGATION appHMIType and activated.
-- In case:
-- 1) Mobile app requests StartService (RPC, encryption = true)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (RPC, REQUEST_RECEIVED) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- 4) send OnStatusUpdate(UPDATE_NEEDED)
-- In case:
-- 2) Policy Table Update is Failed
-- SDL does:
-- 1) send OnStatusUpdate(UPDATE_NEEDED)
-- 2) send OnServiceUpdate (RPC, REQUEST_REJECTED, PTU_FAILED) to HMI
-- 3) send StartServiceNACK(RPC) to mobile app
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ServiceStatusUpdateToHMI/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions]]
function common.onServiceUpdateFunc(pServiceTypeValue)
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate",
    { serviceEvent = "REQUEST_RECEIVED", serviceType = pServiceTypeValue, appID = common.getHMIAppId() },
    { serviceEvent = "REQUEST_REJECTED",
      serviceType = pServiceTypeValue,
      reason = "PTU_FAILED",
      appID = common.getHMIAppId() })
  :Times(2)
end

function common.serviceResponseFunc(pServiceId)
  common.getMobileSession():ExpectControlMessage(pServiceId, {
    frameInfo = common.frameInfo.START_SERVICE_NACK,
    encryption = false
  })
end

local function policyTableUpdateUnsuccess()
  local pPTUpdateFunc = function(pTbl)
    pTbl.policy_table.app_policies = nil
  end
  local pExpNotificationFunc = function()
    common.getHMIConnection():ExpectRequest("VehicleInfo.GetVehicleData")
    :Times(0)
    common.getHMIConnection():ExpectRequest("BasicCommunication.DecryptCertificate")
    :Times(0)
  end
  common.policyTableUpdate(pPTUpdateFunc, pExpNotificationFunc)
end

function common.policyTableUpdateFunc()
  common.getHMIConnection():ExpectNotification("SDL.OnStatusUpdate",
    { status = "UPDATE_NEEDED" }, { status = "UPDATING" },
    { status = "UPDATE_NEEDED" })
  :Times(3)
  policyTableUpdateUnsuccess()
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Init SDL certificates", common.initSDLCertificates,
  { "./files/Security/client_credential_expired.pem", true })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App registration", common.registerApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate)
runner.Step("App activation", common.activateApp)

runner.Title("Test")
runner.Step("Start RPC Service protected", common.startServiceWithOnServiceUpdate, { 7, 0 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
