---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: The attempt to open the protected Video, Audio, RPC services with unsuccessful
--  OnStatusUpdate(REQUEST_REJECTED, INVALID_TIME) notification by receiving GetSystemTime response with error code
--  from HMI and services are not force protected and not force unprotected
-- Precondition:
-- 1) App is registered with NAVIGATION appHMIType and activated.
-- In case:
-- 1) Mobile app requests StartService (Video, encryption = true)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (VIDEO, REQUEST_RECEIVED) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- In case: HMI send GetSystemTime_Rq(REJECTED) to SDL
-- SDL does:
-- 1) send OnServiceUpdate (RPC, INVALID_TIME) to HMI
-- 2) send OnServiceUpdate (VIDEO, AUDIO, REQUEST_ACCEPTED) to HMI
-- 3) send StartServiceACK(Video, Audio), encryption = false, StartServiceNACK(RPC), encryption = false to mobile app
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ServiceStatusUpdateToHMI/common')
local events = require("events")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

-- [[ Local function ]]
function common.getSystemTimeRes(pData)
  common.getHMIConnection():SendError(pData.id, pData.method, "REJECTED", "Time is not provided")
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
      :Times(2)
  end
  local startserviceEvent = events.Event()
    startserviceEvent.level = 3
    startserviceEvent.matches = function(_, data)
    return
    data.method == "BasicCommunication.GetSystemTime"
  end

  common.getHMIConnection():ExpectEvent(startserviceEvent, "GetSystemTime")
  :Do(function(_, data)
      common.getSystemTimeRes(data)
    end)
end

function common.serviceResponseFunc(pServiceId, pStreamingFunc)
  common.serviceResponseWithACKandNACK(pServiceId, pStreamingFunc)
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
runner.Step("Start Video Service protected with rejected GetSystemTime request",
  common.startServiceWithOnServiceUpdate, { 11, 0 })
runner.Step("Start Audio Service protected with rejected GetSystemTime request",
  common.startServiceWithOnServiceUpdate, { 10, 0 })
runner.Step("Start RPC Service protected with rejected GetSystemTime request",
  common.startServiceWithOnServiceUpdate, { 7, 0 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
