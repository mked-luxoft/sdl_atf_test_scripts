---------------------------------------------------------------------------------------------------
-- User story: Smoke
-- Use case: SetAppIcon
-- Item: Happy path
--
-- Requirement summary:
-- [SetAppIcon] SUCCESS: getting SUCCESS:UI.SetAppIcon()
--
-- Description:
-- Mobile application sends valid SetAppIcon request and gets UI.SetAppIcon "SUCCESS" response from HMI

-- Pre-conditions:
-- a. HMI and SDL are started
-- b. appID is registered and activated on SDL
-- c. appID is currently in Background, Full or Limited HMI level

-- Steps:
-- appID requests SetAppIcon with valid parameters

-- Expected:
-- SDL validates parameters of the request
-- SDL checks if UI interface is available on HMI
-- SDL checks if SetAppIcon is allowed by Policies
-- SDL checks if all parameters are allowed by Policies
-- SDL transfers the UI part of request with allowed parameters to HMI
-- SDL receives UI part of response from HMI with "SUCCESS" result code
-- SDL responds with (resultCode: SUCCESS, success:true) to mobile application
---------------------------------------------------------------------------------------------------

--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonSmoke = require('test_scripts/Smoke/commonSmoke')

--[[ Local Variables ]]
local putFileParams = {
  requestParams = {
    syncFileName = 'action.png',
    fileType = "GRAPHIC_PNG",
    persistentFile = false,
    systemFile = false
  },
  filePath = "files/icon.png"
}

local requestParams = {
  syncFileName = "action.png"
}

local requestUiParams = {
  syncFileName = {
    imageType = "DYNAMIC",
    -- value = commonSmoke.getPathToFileInStorage(requestParams.syncFileName)
  }
}

local allParams = {
  requestParams = requestParams,
  requestUiParams = requestUiParams
}

--[[ Local Functions ]]
local function setAppIcon(params, self)
  local cid = self.mobileSession1:SendRPC("SetAppIcon", params.requestParams)
  params.requestUiParams.appID = commonSmoke.getHMIAppId()
  params.requestUiParams.syncFileName.value = commonSmoke.getPathToFileInStorage(requestParams.syncFileName)
  EXPECT_HMICALL("UI.SetAppIcon", params.requestUiParams)
  :Do(function(_, data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
    end)
  self.mobileSession1:ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonSmoke.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonSmoke.start)
runner.Step("RAI", commonSmoke.registerApp)
runner.Step("Activate App", commonSmoke.activateApp)
runner.Step("Upload icon file", commonSmoke.putFile, { putFileParams })

runner.Title("Test")
runner.Step("SetAppIcon Positive Case", setAppIcon, { allParams })

runner.Title("Postconditions")
runner.Step("Stop SDL", commonSmoke.postconditions)
