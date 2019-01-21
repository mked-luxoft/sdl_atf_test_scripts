---------------------------------------------------------------------------------------------------
-- Common module
---------------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.SecurityProtocol = "DTLS"
config.application1.registerAppInterfaceParams.appName = "server"
config.application1.registerAppInterfaceParams.fullAppID = "SPT"

--[[ Required Shared libraries ]]
local actions = require("user_modules/sequences/actions")
local utils = require("user_modules/utils")
local common = require("test_scripts/Security/SSLHandshakeFlow/common")

--[[ Variables ]]
local m = actions

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

function m.activateAppProtected()
  local cid = m.getHMIConnection():SendRequest("SDL.ActivateApp", { appID = m.getHMIAppId() })
  m.getHMIConnection():ExpectResponse(cid)
  m.getMobileSession():ExpectEncryptedNotification("OnHMIStatus", {
    hmiLevel = "FULL", audioStreamingState = "AUDIBLE", systemContext = "MAIN" })
end
function m.ptUpdate(pTbl)
  local filePath = "./files/Security/client_credential.pem"
  local crt = utils.readFile(filePath)
  pTbl.policy_table.module_config.certificate = crt
end

m.postconditions = common.postconditions
local postconditionsOrig = m.postconditions

local preconditionsOrig = m.preconditions
  function m.preconditions()
  preconditionsOrig()
  common.initSDLCertificates("./files/Security/client_credential.pem", false)
end

function m.preconditions()
  preconditionsOrig()
  m.cleanUpCertificates()
end

function m.postconditions()
  postconditionsOrig()
  m.cleanUpCertificates()
end

local policyTableUpdate_orig = m.policyTableUpdate

function m.policyTableUpdate(pPTUpdateFunc)
  local function expNotificationFunc()
    m.getHMIConnection():ExpectRequest("BasicCommunication.DecryptCertificate")
    :Do(function(_, d)
        m.getHMIConnection():SendResponse(d.id, d.method, "SUCCESS", { })
      end)
    :Times(AnyNumber())
    m.getHMIConnection():ExpectRequest("VehicleInfo.GetVehicleData", { odometer = true })
  end
  policyTableUpdate_orig(pPTUpdateFunc, expNotificationFunc)
end

return m
