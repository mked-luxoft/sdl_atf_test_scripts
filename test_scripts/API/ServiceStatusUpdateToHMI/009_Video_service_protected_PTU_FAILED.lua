---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: The attempt to open the protected Video service with unsuccessful OnStatusUpdate(REQUEST_REJECTED,
-- PTU_FAILED) notification by unsuccessful PTU
-- Precondition:
-- 1) App is registered with NAVIGATION appHMIType and activated.
-- In case:
-- 1) Mobile app requests StartService (Video, encryption = true)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (VIDEO, REQUEST_RECEIVED) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- 4) send OnStatusUpdate(UPDATE_NEEDED)
-- In case:
-- 2) Policy Table Update is Failed
-- SDL does:
-- 1) send OnStatusUpdate(UPDATE_NEEDED)
-- 2) send OnServiceUpdate (VIDEO, REQUEST_REJECTED, PTU_FAILED) to HMI
-- 3) send StartServiceNACK(Video) to mobile app
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ServiceStatusUpdateToHMI/common')
local utils = require("user_modules/utils")

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
  :Timeout(65000)
end

function common.serviceResponseFunc(pServiceId)
  common.getMobileSession():ExpectControlMessage(pServiceId, {
    frameInfo = common.frameInfo.START_SERVICE_NACK,
    encryption = false
  })
  :Timeout(65000)
end

function common.policyTableUpdateFunc()
  common.getHMIConnection():ExpectNotification("SDL.OnStatusUpdate",
  { status = "UPDATE_NEEDED" }, { status = "UPDATING" },
  { status = "UPDATE_NEEDED" }, { status = "UPDATING" })
  :Times(4)
  :Timeout(65000)
  :Do(function(exp, data)
    if exp.occurences == 2 and data.params.status == "UPDATING" then
      utils.cprint(35, "Waiting for PTU retry")
    end
  end)

  common.policyTableUpdateUnsuccess()

  common.wait(65000)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions, { "0x0B" })
runner.Step("Init SDL certificates", common.initSDLCertificates,
  { "./files/Security/client_credential_expired.pem", false })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App registration", common.registerApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate)
runner.Step("App activation", common.activateApp)

runner.Title("Test")
runner.Step("Start Video Service protected", common.startServiceWithOnServiceUpdate, { 11, 0 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
