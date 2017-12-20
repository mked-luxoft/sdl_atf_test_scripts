---------------------------------------------------------------------------------------------------
-- Description
-- SDL must start heartbeat only after first Heartbeat request from mobile app
-- Preconditions
-- SDL and HMI are started.
-- mobile app successfully connects to SDL over protocol v3 or higher
-- the value of "HeartBeat" param at .ini file is more than zero
-- Steps to reproduce
-- App sends first HeartBeat request by itself over control service to SDL
-- Actual result
-- SDL start HeartBeat process right after first StartService_request from mobile app
-- Expected result
-- SDL must respond HeartBeat_ACK over control service to mobile app start HeartBeat timeout (defined at .ini file)
-- SDL must NOT start HeartBeat process right after first StartService_request from mobile app(as currently implemented)
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonDefects = require('test_scripts/Defects/4_5/commonDefects')
local commonFunctions = require('user_modules/shared_testcases/commonFunctions')
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')
local mobile_session = require('mobile_session')
local constants = require('protocol_handler/ford_protocol_constants')
local events = require('events')
local mobile = require('mobile_connection')
local tcp = require('tcp_connection')
local file_connection = require('file_connection')

--[[ General configuration parameters ]]
config.heartbeatTimeout = 7000

--[[ Local Functions ]]
local function BackUpIniFileAndSetHBValue()
  commonPreconditions:BackupFile("smartDeviceLink.ini")
  commonFunctions:write_parameter_to_smart_device_link_ini("HeartBeatTimeout", 5000)
end

local function RestoreIniFile()
  commonPreconditions:RestoreFile("smartDeviceLink.ini")
end

local function OpenConnectionCreateSession(self)
  config.defaultProtocolVersion = 3
  local tcpConnection = tcp.Connection(config.mobileHost, config.mobilePort)
  local fileConnection = file_connection.FileConnection("mobile.out", tcpConnection)
  self.mobileConnection = mobile.MobileConnection(fileConnection)
  self.mobileSession1= mobile_session.MobileSession(
    self,
    self.mobileConnection)
  event_dispatcher:AddConnection(self.mobileConnection)
  self.mobileSession1:ExpectEvent(events.connectedEvent, "Connection 1 started")
  self.mobileConnection:Connect()
  self.mobileSession1.activateHeartbeat = false
  self.mobileSession1.sendHeartbeatToSDL = false
  self.mobileSession1.answerHeartbeatFromSDL = false
  self.mobileSession1.ignoreHeartBeatAck = false
  self.mobileSession1:StartService(7)
end

local function RegisterAppInterface(self)
  local CorIdRegister = self.mobileSession1:SendRPC("RegisterAppInterface", {
      syncMsgVersion ={
        majorVersion = 4,
        minorVersion = 3
      },
      appName = config.application1.registerAppInterfaceParams.appName,
      isMediaApplication = true,
      languageDesired = 'EN-US',
      hmiDisplayLanguageDesired = 'EN-US',
      appHMIType = { "DEFAULT" },
      appID = config.application1.registerAppInterfaceParams.appID
    })
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered",
    { application = {appName = config.application1.registerAppInterfaceParams.appName }})
  self.mobileSession1:ExpectResponse(CorIdRegister, { success = true, resultCode = "SUCCESS" })
  self.mobileSession1:ExpectNotification("OnHMIStatus",
    { systemContext = "MAIN", hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE" })
end

local function ExpectationAfterAppRegistration(self)
  local hmiAppId = commonDefects.getHMIAppId(1)
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppUnregistered",
    {unexpectedDisconnect = true, appID = hmiAppId})
  :Times(0)
  commonFunctions:userPrint (33,"Log: AppSession started, HB disabled")
  commonFunctions:userPrint (33, "Log: App v.3 disconnection not expected since no HB ACK and timer" ..
  "should be started by SDL till the HB request from app first")
  local HBEvent = events.Event()
  HBEvent.matches =
  function(_, data)
    return data.frameType == 0 and
    data.serviceType == 0 and
    (data.sessionId == self.mobileSession1.sessionId) and
    data.frameInfo == 0
  end
  self.mobileSession1:ExpectEvent(HBEvent, "HB")
  :Times(0)
  commonDefects.delayedExp(10000)
end

local function sendHBFromMobileAndReceivingFromSDL(self)
  local HBEvent = events.Event()
  HBEvent.matches =
  function(_, data)
    return data.frameType == 0 and
    data.serviceType == 0 and
    (data.sessionId == self.mobileSession1.sessionId) and
    data.frameInfo == 0
  end
  local HBACKEvent = events.Event()
  HBACKEvent.matches =
  function(_, data)
    return data.frameType == 0 and
    data.serviceType == 0 and
    (data.sessionId == self.mobileSession1.sessionId) and
    data.frameInfo == 255
  end
  self.mobileSession1:Send({
      frameType = constants.FRAME_TYPE.CONTROL_FRAME,
      serviceType = constants.SERVICE_TYPE.CONTROL,
      frameInfo = constants.FRAME_INFO.HEARTBEAT
    })
  self.mobileSession1:ExpectEvent(HBEvent, "HB")
  self.mobileSession1:ExpectEvent(HBACKEvent, "HB")
end

local function DisconnectDueToHeartbeat()
  local hmiAppId = commonDefects.getHMIAppId(1)
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppUnregistered", {unexpectedDisconnect = true, appID = hmiAppId})
  commonDefects.delayedExp()
  commonFunctions:userPrint(33, "AppSession started, HB enabled")
  commonFunctions:userPrint(33, "In DisconnectDueToHeartbeat TC disconnection is expected because HB process started" ..
  "by SDL after app's HB request")
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonDefects.preconditions)
runner.Step("BackUpIniFileAndSetHBValue", BackUpIniFileAndSetHBValue)
runner.Step("Start SDL, HMI", commonDefects.startWithoutMobile)

runner.Title("Test")
runner.Step("OpenConnectionCreateSession", OpenConnectionCreateSession)
runner.Step("RegisterApp", RegisterAppInterface)
runner.Step("ExpectationAfterAppRegistration", ExpectationAfterAppRegistration)
runner.Step("SendHBFromMobileAndExpectationHBFromSDL", sendHBFromMobileAndReceivingFromSDL)
runner.Step("DisconnectDueToHeartbeat", DisconnectDueToHeartbeat)

runner.Title("Postconditions")
runner.Step("Stop SDL", commonDefects.postconditions)
runner.Step("RestoreIniFile", RestoreIniFile)