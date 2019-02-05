---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: Receiving of the OnStatusUpdate notification by the appropriate app by the Audio, Video services opening
-- 1) App_1 is registered with NAVIGATION appHMIType and activated.
-- 2) App_2 is registered with NAVIGATION appHMIType.
-- In case:
-- 1) Mobile app_1 requests StartService (Video, encryption = true)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (VIDEO, REQUEST_RECEIVED) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- 4) send OnStatusUpdate(UPDATE_NEEDED)
-- In case:
-- 2) Policy Table Update is Successful
-- SDL does:
-- 1) send OnStatusUpdate(UP_TO_DATE) if Policy Table Update is successful
-- 2) send BC.DecryptCertificate_Rq() and wait response from HMI BC.DecryptCertificate_Rq()(only in EXTERNAL_PROPRIETARY
--    flow)
-- 3) send OnServiceUpdate (VIDEO, REQUEST_ACCEPTED) to HMI
-- 4) send StartServiceACK(Video) to mobile app_1
-- In case:
-- 3) Mobile app_1 send Video Data
-- SDL does:
-- 1) send OnVideoDataStreaming (true) to HMI
-- In case:
-- 4) App_2 activated and requests StartService (Video, encryption = true)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (VIDEO, REQUEST_RECEIVED) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- 4) send OnStatusUpdate(UPDATE_NEEDED)
-- 5) send OnStatusUpdate(UP_TO_DATE) if Policy Table Update is successful
-- 6) send BC.DecryptCertificate_Rq() and wait response from HMI BC.DecryptCertificate_Rq()(only in EXTERNAL_PROPRIETARY
--    flow)
-- 7) send OnServiceUpdate (VIDEO, REQUEST_ACCEPTED) to HMI
-- 8) send StartServiceACK(Video) to mobile app_2
-- 9) Mobile app_2 send Video Data
-- 10) send OnVideoDataStreaming (true) to HMI
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ServiceStatusUpdateToHMI/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Function ]]
function common.serviceResponseFunc(pServiceId, _, pAppId)
  common.getMobileSession(pAppId):ExpectControlMessage(pServiceId, {
    frameInfo = common.frameInfo.START_SERVICE_ACK,
    encryption = true
  })
end

common.policyTableUpdateFunc = function() end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Init SDL certificates", common.initSDLCertificates,
  { "./files/Security/client_credential.pem", true })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App 1 registration", common.registerApp, { 1 })
runner.Step("PolicyTableUpdate for app 1", common.policyTableUpdate)
runner.Step("App 2 registration", common.registerApp, { 2 })
runner.Step("PolicyTableUpdate for app 2", common.policyTableUpdate)

runner.Title("Test")
runner.Step("App 1 activation", common.activateApp, { 1 })
runner.Step("Start Video Service app 1", common.startServiceWithOnServiceUpdate, { 11, 1, 1 })
runner.Step("Start Audio Service app 1", common.startServiceWithOnServiceUpdate, { 10, 1, 1 })
runner.Step("App 2 activation", common.activateApp, { 2 })
runner.Step("Start Video Service app 2", common.startServiceWithOnServiceUpdate, { 11, 1, 2 })
runner.Step("Start Audio Service app 2", common.startServiceWithOnServiceUpdate, { 10, 1, 2 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
