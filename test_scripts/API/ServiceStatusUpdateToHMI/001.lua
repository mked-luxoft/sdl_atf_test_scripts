---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description:
-- Precondition:
-- 1) App registered with NAVIGATION appHMIType and activated.
-- In case:
-- 1) Mobile app requests StartService (Video, encryption = true)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (VIDEO, REQUEST_RECEIVED) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Rq()
-- 4) send OnStatusUpdate(UPDATE_NEEDED)
-- In case:
-- 2) Policy Table Update is Successful
-- SDL does:
-- 1) send OnStatusUpdate(UP_TO_DATE) if Policy Table Update is successful
-- 2) send BC.DecryptCertificate_Rq() and wait response from HMI BC.DecryptCertificate_Rq()
-- 3) send OnServiceUpdate (VIDEO, REQUEST_ACCEPTED) to HMI
-- 4) send StartServiceACK(Video) to mobile app
-- In case:
-- 3) Mobile app send Video Data
-- SDL does:
-- 1) send OnVideoDataStreaming (true) to HMI
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ServiceStatusUpdateToHMI/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false
config.application1.registerAppInterfaceParams.appHMIType = { "NAVIGATION" }

-- [[ Local function ]]
local function startServiceProtected(pServiceId)
  common.getMobileSession():StartSecureService(pServiceId)
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate", {
    serviceEvent = "REQUEST_RECEIVED", serviceType = "VIDEO"
  })
  :Do(function()
    common.getHMIConnection():ExpectNotification("SDL.OnStatusUpdate",
    { status = "UPDATE_NEEDED" }, { status = "UPDATING" }, { status = "UP_TO_DATE" })
    :Times(3)
    :Do(function()
      common.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate", {
        serviceEvent = "REQUEST_ACCEPTED", serviceType = "VIDEO"
      })
    end)
  end)
  common.getMobileSession():ExpectControlMessage(pServiceId, {
    frameInfo = common.frameInfo.START_SERVICE_ACK,
    encryption = true
  })
  common.getMobileSession():ExpectHandshakeMessage()
  :Times(1)
  local function ptUpdate(pTbl)
    local filePath = "./files/Security/client_credential.pem"
    local crt = common.readFile(filePath)
    pTbl.policy_table.module_config.certificate = crt
  end
  common.policyTableUpdateSuccess(ptUpdate)
end

local function appStartVideoStreaming(pServiceId)
  common.getHMIConnection():ExpectRequest("Navigation.StartStream")
  :Do(function(_, data)
    common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {})
    common.getMobileSession():StartStreaming(pServiceId, "files/SampleVideo_5mb.mp4")
    common.getHMIConnection():ExpectNotification("Navigation.OnVideoDataStreaming", { available = true })
  end)
  common.getMobileSession():ExpectNotification("OnHMIStatus")
  :Times(0)
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
runner.Step("Start RPC Service protected", startServiceProtected, { 11 })
runner.Step("Start streaming", appStartVideoStreaming, { 11 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
