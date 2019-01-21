---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: Opening of the protected Audio service with succeeded OnStatusUpdate notifications
-- Precondition:
-- 1) App is registered with NAVIGATION appHMIType and activated.
-- In case:
-- 1) Mobile app requests StartSream (Audio, encryption = true)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (AUDIO, REQUEST_RECEIVED) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- 4) send OnStatusUpdate(UPDATE_NEEDED)
-- In case:
-- 2) Policy Table Update is Successful
-- SDL does:
-- 1) send OnStatusUpdate(UP_TO_DATE) if Policy Table Update is successful
-- 2) send BC.DecryptCertificate_Rq() and wait response from HMI BC.DecryptCertificate_Rq()(only in EXTERNAL_PROPRIETARY
--    flow)
-- 3) send OnServiceUpdate (AUDIO, REQUEST_ACCEPTED) to HMI
-- 4) send StartServiceACK(Audio) to mobile app
-- In case:
-- 3) Mobile app send Audio Data
-- SDL does:
-- 1) send OnAudioDataStreaming (true) to HMI
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ServiceStatusUpdateToHMI/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

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
runner.Step("Start Audio Service protected", common.startServiceWithOnServiceUpdate, { 10 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
