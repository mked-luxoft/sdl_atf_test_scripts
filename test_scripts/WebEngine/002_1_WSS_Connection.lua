---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0240-sdl-js-pwa.md
--
-- Description:
-- Successfully registering the Web application over the WebSocket-Secure connection
--
-- Precondition:
-- 1. SDL and HMI are started
--
-- Sequence:
-- 1. Create WebSocket-Secure connection
--  a. SDL successfully established a  WebSocket-Secure  connection
-- 2. Register the Web application
--  a. Web application is registered successfully
-- 3. Activate the Web application
--  a. Web application is activated successfully on the HMI and it has FULL level
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local actions = require("user_modules/sequences/actions")

--[[ Conditions to scik test ]]
if config.defaultMobileAdapterType == "WS" then
  runner.skipTest("Test is not applicable for WS connection")
end

--[[ General configuration parameters ]]
config.defaultProtocolVersion = 2
runner.testSettings.isSelfIncluded = false

config.wssCertificateCAPath = "./files/WebEngine/ca-cert.pem"
config.wssCertificateClientPath = "./files/WebEngine/client-cert.pem"
config.wssPrivateKeyPath = "./files/WebEngine/client-key.pem"

--[[ Local Functions ]]
local function start(pHMIParams)
  local event = actions.run.createEvent()
  actions.init.SDL()
  :Do(function()
      actions.init.HMI()
      :Do(function()
        actions.init.HMI_onReady(pHMIParams)
        :Do(function()
          actions.hmi.getConnection():RaiseEvent(event, "Start event")
          end)
        end)
    end)
  return actions.hmi.getConnection():ExpectEvent(event, "Start event")
end

local function connectWebEngine(pMobConnId)
  local url = "wss://localhost"
  local port = 2020
  actions.mobile.createConnection(pMobConnId, url, port, actions.mobile.CONNECTION_TYPE.WSS)
  actions.mobile.connect(pMobConnId)
  :Do(function()
      local conType = config.defaultMobileAdapterType
      config.defaultMobileAdapterType = "WSS"
      actions.mobile.allowSDL(pMobConnId)
      config.defaultMobileAdapterType = conType
    end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", actions.preconditions)
runner.Step("Start SDL, HMI, connect regular mobile, start Session", start)

runner.Title("Test")
runner.Step("Connect WebEngine device", connectWebEngine, { 1 })
runner.Step("RAI of web app", actions.app.register, { 1, 1 })
runner.Step("Activate web app", actions.app.activate, { 1 })

runner.Title("Postconditions")
runner.Step("Stop SDL", actions.postconditions)
