---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0240-sdl-js-pwa.md
--
-- Description:
-- Verify that the SDL does not establish WebSocket-Secure connection in case of WS Server Certificate
--  does not define in SmartDeviceLink.ini file
--
-- Precondition:
-- 1. SDL and HMI are started
--
-- Sequence:
-- 1. Create WebSocket-Secure connection
--  a. SDL does not establish WebSocket-Secure connection
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local actions = require("user_modules/sequences/actions")
local events = require("events")
local utils = require("user_modules/utils")
local hmi_values = require('user_modules/hmi_values')

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

--[[ Local Variables ]]
local sslParametersServer = {
  "WSServerCertificatePath",
  "WSServerKeyPath",
  "WSServerCACertificatePath"
}

--[[ Local Functions ]]
local function start()
  local hmiValues = hmi_values.getDefaultHMITable()
  hmiValues.BasicCommunication.UpdateDeviceList.occurrence = 0
  local event = actions.run.createEvent()
  actions.init.SDL()
  :Do(function()
      actions.init.HMI()
      :Do(function()
        actions.init.HMI_onReady(hmiValues)
        :Do(function()
          actions.hmi.getConnection():RaiseEvent(event, "Start event")
          end)
        end)
    end)
  return actions.hmi.getConnection():ExpectEvent(event, "Start event")
end

local function checkConnection(pMobConnId)
  local connection = actions.mobile.getConnection(pMobConnId)
  connection:ExpectEvent(events.disconnectedEvent, "Disconnected")
  :Times(AnyNumber())
  :DoOnce(function()
      utils.cprint(35, "Mobile #" .. pMobConnId .. " disconnected")
    end)
  connection:ExpectEvent(events.connectedEvent, "Connected")
  :Times(0)
  connection:Connect()
end

local function connectWSSWebEngine(pMobConnId)
  local url = "wss://localhost"
  local port = 2020
  actions.mobile.createConnection(pMobConnId, url, port, actions.mobile.CONNECTION_TYPE.WSS)
  checkConnection(pMobConnId)
end

--[[ Scenario ]]
for _, value  in ipairs(sslParametersServer) do
  runner.Title("Preconditions")
  runner.Step("Clean environment", actions.preconditions)
  runner.Step("Replace WS Server Certificate parameters in smartDeviceLink.ini file", actions.setSDLIniParameter, { value, " " })
  runner.Step("Start SDL, HMI, connect regular mobile, start Session", start)

  runner.Title("Test")
  runner.Step("Connect WebEngine device", connectWSSWebEngine, { 1 })

  runner.Title("Postconditions")
  runner.Step("Stop SDL", actions.postconditions)
end
