---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: The attempt to open the protected Video, Audio, RPC services with unsuccessful
--  OnStatusUpdate(REQUEST_REJECTED, INVALID_CERT) notification by receiving DecryptCertificate response with error code
--  from HMI and services are not force protected
-- Precondition:
-- 1) App is registered with NAVIGATION appHMIType and activated.
-- In case:
-- 1) Mobile app requests StartService (Video, encryption = false)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (VIDEO, REQUEST_RECEIVED) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- 4) send OnStatusUpdate(UPDATE_NEEDED)
-- In case:
-- 2) Policy Table Update is Successful
-- SDL does:
-- 1) send OnStatusUpdate(UP_TO_DATE) if Policy Table Update is successful
-- 2) send BC.DecryptCertificate_Rq() and wait response from HMI BC.DecryptCertificate_Rq()
-- In case:
-- 3) Determines that cert is invalid
-- SDL does:
-- 1) send OnServiceUpdate (RPC, INVALID_CERT) to HMI
-- 2) send OnServiceUpdate (VIDEO, AUDIO, REQUEST_ACCEPTED) to HMI
-- 3) send StartServiceACK(Video, Audio), encryption = false, StartServiceNACK(RPC), encryption = false to mobile app
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ServiceStatusUpdateToHMI/common')
local events = require("events")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
function common.decryptCertificateRes(pData)
  common.getHMIConnection():SendError(pData.id, pData.method, "REJECTED", "Cert is not decrypted")
end

function common.onServiceUpdateFunc(pServiceTypeValue)
  if pServiceTypeValue == "RPC" then
    common.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate",
      { serviceEvent = "REQUEST_RECEIVED", serviceType = pServiceTypeValue, appID = common.getHMIAppId() },
      { serviceEvent = "REQUEST_REJECTED",
        serviceType = pServiceTypeValue,
        reason = "INVALID_TIME", appID = common.getHMIAppId()
      })
    :Times(2)
  else
    common.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate",
      { serviceEvent = "REQUEST_RECEIVED", serviceType = pServiceTypeValue, appID = common.getHMIAppId() },
      { serviceEvent = "REQUEST_ACCEPTED", serviceType = pServiceTypeValue, appID = common.getHMIAppId() })
  end
  local startserviceEvent = events.Event()
  startserviceEvent.level = 3
    startserviceEvent.matches = function(_, data)
      return
      data.method == "BasicCommunication.DecryptCertificate"
    end

  common.getHMIConnection():ExpectEvent(startserviceEvent, "DecryptCertificate")
  :Do(function(_, data)
      common.decryptCertificateRes(data)
    end)
end

function common.serviceResponseFunc(pServiceId, pStreamingFunc)
  if pServiceId ~= 7 then
    common.getMobileSession():ExpectControlMessage(pServiceId, {
      frameInfo = common.frameInfo.START_SERVICE_ACK,
      encryption = false
    })
    :Do(function(_, data)
      if data.frameInfo == common.frameInfo.START_SERVICE_ACK then
        pStreamingFunc()
      end
    end)
  else
    common.getMobileSession():ExpectControlMessage(pServiceId, {
      frameInfo = common.frameInfo.START_SERVICE_NACK,
      encryption = false
    })
  end
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Init SDL certificates", common.initSDLCertificates,
  { "./files/Security/client_credential_expired.pem", false })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App registration", common.registerApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate)
runner.Step("App activation", common.activateApp)

runner.Title("Test")
runner.Step("Start Video Service protected", common.startServiceWithOnServiceUpdate, { 11, 0 })
runner.Step("Start Audio Service protected", common.startServiceWithOnServiceUpdate, { 10, 0 })
runner.Step("Start RPC Service protected", common.startServiceWithOnServiceUpdate, { 7, 0 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
