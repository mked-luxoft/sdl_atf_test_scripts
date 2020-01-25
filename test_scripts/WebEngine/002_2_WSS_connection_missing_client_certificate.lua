---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0240-sdl-js-pwa.md
--
-- Description:
-- Verify that the SDL does not establish WebSocket-Secure connection in case of  WS Client Certificate is not define
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

--[[ Conditions to scik test ]]
if config.defaultMobileAdapterType == "WS" then
  runner.skipTest("Test is not applicable for WS connection")
end

--[[ General configuration parameters ]]
config.defaultProtocolVersion = 2
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local pSslParametersMissingClientCert = {
  caCertPath = "./files/WebEngine/ca-cert.pem",
  certPath = "",
  keyPath = "./files/WebEngine/client-key.pem"
}

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

local function checkConnection(pMobConnId)
  local connection = actions.mobile.getConnection(pMobConnId)
  connection:ExpectEvent(events.disconnectedEvent, "Disconnected")
  :Pin()
  :Times(AnyNumber())
  :Do(function()
      utils.cprint(35, "Mobile #" .. pMobConnId .. " disconnected")
    end)
  connection:ExpectEvent(events.connectedEvent, "Connected")
  :Times(0)
  connection:Connect()
end

local function connectWSSWebEngine(pMobConnId, pSslParameters)
  local url = "wss://localhost"
  local port = 2020
  actions.mobile.createConnection(pMobConnId, url, port, actions.mobile.CONNECTION_TYPE.WSS, pSslParameters)
  checkConnection(pMobConnId)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", actions.preconditions)
runner.Step("Start SDL, HMI, connect regular mobile, start Session", start)
runner.Title("Test")
runner.Step("Connect WebEngine device", connectWSSWebEngine, { 1, pSslParametersMissingClientCert })

runner.Title("Postconditions")
runner.Step("Stop SDL", actions.postconditions)
