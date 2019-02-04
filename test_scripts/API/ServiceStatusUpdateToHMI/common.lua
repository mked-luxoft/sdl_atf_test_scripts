---------------------------------------------------------------------------------------------------
-- Common module
---------------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.SecurityProtocol = "DTLS"
config.application1.registerAppInterfaceParams.appName = "server"
config.application1.registerAppInterfaceParams.fullAppID = "SPT"
config.application1.registerAppInterfaceParams.appHMIType = { "NAVIGATION" }
config.application2.registerAppInterfaceParams.appHMIType = { "NAVIGATION" }

--[[ Required Shared libraries ]]
local actions = require("user_modules/sequences/actions")
local utils = require("user_modules/utils")
local common = require("test_scripts/Security/SSLHandshakeFlow/common")
local events = require("events")

--[[ Variables ]]
local m = actions
m.wait = utils.wait

--[[ Common Functions ]]
function m.getSystemTimeValue()
  return {
    millisecond = 100,
    second = 30,
    minute = 29,
    hour = 15,
    day = 20,
    month = 3,
    year = 2018,
    tz_hour = -3,
    tz_minute = 10
  }
end

local startOrigin =  m.start
function m.start()
  startOrigin()
  actions.getHMIConnection():ExpectRequest("BasicCommunication.GetSystemTime")
  :Do(function(_, data)
      actions.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { systemTime = m.getSystemTimeValue() })
    end)
  :Pin()
  :Times(AnyNumber())
end

function m.ptUpdate(pTbl)
  local filePath = "./files/Security/client_credential.pem"
  local crt = utils.readFile(filePath)
  pTbl.policy_table.module_config.certificate = crt
end

local preconditionsOrig = common.preconditions
function m.preconditions(pForceProtectedServices, pForceUnprotectedServices)
  preconditionsOrig()
  if not pForceProtectedServices then pForceProtectedServices = "Non" end
  if not pForceUnprotectedServices then pForceUnprotectedServices = "Non" end
  m.setSDLIniParameter("ForceProtectedService", pForceProtectedServices)
  m.setSDLIniParameter("ForceUnprotectedService", pForceUnprotectedServices)
end

local postconditionsOrig = common.postconditions
function m.postconditions()
  postconditionsOrig()
  m.restoreSDLIniParameters()
end

local policyTableUpdate_orig = m.policyTableUpdate
function m.policyTableUpdate(pPTUpdateFunc, pExpNotificationFunc)
  local function expNotificationFunc()
    if pExpNotificationFunc then
      pExpNotificationFunc()
    else
      m.getHMIConnection():ExpectRequest("BasicCommunication.DecryptCertificate")
      :Do(function(_, d)
          m.getHMIConnection():SendResponse(d.id, d.method, "SUCCESS", { })
        end)
      :Times(AnyNumber())
      m.getHMIConnection():ExpectRequest("VehicleInfo.GetVehicleData", { odometer = true })
    end
  end
  policyTableUpdate_orig(pPTUpdateFunc, expNotificationFunc)
end

function m.startStream()
  m.getHMIConnection():ExpectRequest("Navigation.StartStream")
  :Do(function(_, data)
    m.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {})
  end)
end

function m.startAudioStream()
  m.getHMIConnection():ExpectRequest("Navigation.StartAudioStream")
  :Do(function(_, data)
    m.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {})
  end)
end

function m.startVideoStreaming(pAppId)
  m.getMobileSession(pAppId):StartStreaming(11, "files/SampleVideo_5mb.mp4")
  m.getHMIConnection():ExpectNotification("Navigation.OnVideoDataStreaming", { available = true })
  m.getMobileSession(pAppId):ExpectNotification("OnHMIStatus")
  :Times(0)
end

function m.startAudioStreaming(pAppId)
  m.getMobileSession(pAppId):StartStreaming(10, "files/tone_mp3.mp3")
  m.getHMIConnection():ExpectNotification("Navigation.OnAudioDataStreaming", { available = true })
  m.getMobileSession(pAppId):ExpectNotification("OnHMIStatus")
  :Times(0)
end

function m.startServiceFunc(pServiceId, pAppId)
  m.getMobileSession(pAppId):StartSecureService(pServiceId)
end

function m.serviceConditionsFunc(pServiceId)
  local serviceTypeValue
  local streamingFunc
  if pServiceId == 11 then
    m.startStream()
    serviceTypeValue = "VIDEO"
    streamingFunc = m.startVideoStreaming
  elseif pServiceId == 10 then
    m.startAudioStream()
    serviceTypeValue = "AUDIO"
    streamingFunc = m.startAudioStreaming
  else
    serviceTypeValue = "RPC"
  end
  return serviceTypeValue, streamingFunc
end

function m.onServiceUpdateFunc(pServiceTypeValue, pAppId)
  m.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate",
    { serviceEvent = "REQUEST_RECEIVED", serviceType = pServiceTypeValue, appID = m.getHMIAppId(pAppId) },
    { serviceEvent = "REQUEST_ACCEPTED", serviceType = pServiceTypeValue, appID = m.getHMIAppId(pAppId) })
  :Times(2)
end

function m.policyTableUpdateFunc()
  m.getHMIConnection():ExpectNotification("SDL.OnStatusUpdate",
  { status = "UPDATE_NEEDED" }, { status = "UPDATING" }, { status = "UP_TO_DATE" })
  :Times(3)

  m.policyTableUpdateSuccess(m.ptUpdate)
end

function m.serviceResponseFunc(pServiceId, pStreamingFunc, pAppId)
  m.getMobileSession(pAppId):ExpectControlMessage(pServiceId, {
    frameInfo = m.frameInfo.START_SERVICE_ACK,
    encryption = true
  })
  :Do(function(_, data)
    if data.frameInfo == m.frameInfo.START_SERVICE_ACK and
    (data.serviceType == 10 or data.serviceType == 11) then
      pStreamingFunc(pAppId)
    end
  end)
end

function m.startServiceWithOnServiceUpdate(pServiceId, pHandShakeExpecTimes, pAppId)
  local serviceTypeValue
  local streamingFunc
  if not pHandShakeExpecTimes then pHandShakeExpecTimes = 1 end

  m.startServiceFunc(pServiceId, pAppId)

  serviceTypeValue, streamingFunc = m.serviceConditionsFunc(pServiceId)

  m.onServiceUpdateFunc(serviceTypeValue, pAppId)

  m.policyTableUpdateFunc()

  m.getMobileSession():ExpectHandshakeMessage()
  :Times(pHandShakeExpecTimes)

  m.serviceResponseFunc(pServiceId, streamingFunc, pAppId)
end

function m.serviceStatusWithGetSystemTimeUnsuccess(pServiceTypeValue, pAppId)
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate",
    { serviceEvent = "REQUEST_RECEIVED", serviceType = pServiceTypeValue, appID = common.getHMIAppId(pAppId) },
    { serviceEvent = "REQUEST_REJECTED",
      serviceType = pServiceTypeValue,
      reason = "INVALID_TIME", appID = common.getHMIAppId(pAppId)
    })
  :Times(2)

  local startserviceEvent = events.Event()
  startserviceEvent.level = 3
    startserviceEvent.matches = function(_, data)
      return
      data.method == "BasicCommunication.GetSystemTime"
    end

  common.getHMIConnection():ExpectEvent(startserviceEvent, "GetSystemTime")
  :Do(function(_, data)
      m.getSystemTimeRes(data)
    end)
end

function common.serviceResponseWithACKandNACK(pServiceId, pStreamingFunc, pTimeout)
  if not pTimeout then pTimeout = 10000 end
  if pServiceId ~= 7 then
    common.getMobileSession():ExpectControlMessage(pServiceId, {
      frameInfo = common.frameInfo.START_SERVICE_ACK,
      encryption = false
    })
    :Timeout(pTimeout)
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
    :Timeout(pTimeout)
  end
end


return m
