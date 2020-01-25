---------------------------------------------------------------------------------------------------
-- User story: Smoke
-- Use case: Show
-- Item: Happy path
--
-- Requirement summary:
-- [Show] SUCCESS: getting SUCCESS:UI.Show()
--
-- Description:
-- Mobile application sends valid Show request and gets UI.Show "SUCCESS" response from HMI

-- Pre-conditions:
-- a. HMI and SDL are started
-- b. appID is registered and activated on SDL
-- c. appID is currently in Background, Full or Limited HMI level

-- Steps:
-- appID requests Show with valid parameters

-- Expected:
-- SDL validates parameters of the request
-- SDL checks if UI interface is available on HMI
-- SDL checks if Show is allowed by Policies
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
    syncFileName = 'icon.png',
    fileType = "GRAPHIC_PNG",
    persistentFile = false,
    systemFile = false
  },
  filePath = "files/icon.png"
}

local requestParams = {
  mainField1 = "mainField1_text",
  mainField2 = "mainField2_text",
  mainField3 = "mainField3_text",
  mainField4 = "mainField4_text",
  templateTitle = "templateTitle_text",
  statusBar = "statusBar_text",
  mediaClock = "mediaClock_text",
  mediaTrack = "mediaTrack_text",
  alignment = "CENTERED",
  graphic = {
    imageType = "DYNAMIC",
    value = "icon.png"
  },
  secondaryGraphic = {
    imageType = "DYNAMIC",
    value = "icon.png"
  },
  metadataTags = {
    mainField1 = { "mediaTitle" },
    mainField2 = { "mediaArtist" },
    mainField3 = { "mediaAlbum" },
    mainField4 = { "mediaYear" },
  }
}

local responseUiParams = {
  showStrings = {
    {
      fieldName = "mainField1",
      fieldText = requestParams.mainField1,
      fieldTypes = requestParams.metadataTags.mainField1
    },
    {
      fieldName = "mainField2",
      fieldText = requestParams.mainField2,
      fieldTypes = requestParams.metadataTags.mainField2
    },
    {
      fieldName = "mainField3",
      fieldText = requestParams.mainField3,
      fieldTypes = requestParams.metadataTags.mainField3
    },
    {
      fieldName = "mainField4",
      fieldText = requestParams.mainField4,
      fieldTypes = requestParams.metadataTags.mainField4
    },
    {
      fieldName = "templateTitle",
      fieldText = requestParams.templateTitle
    },
    {
      fieldName = "mediaClock",
      fieldText = requestParams.mediaClock
    },
    {
      fieldName = "mediaTrack",
      fieldText = requestParams.mediaTrack
    },
    {
      fieldName = "statusBar",
      fieldText = requestParams.statusBar
    }
  },
  alignment = requestParams.alignment,
  graphic = {
    imageType = requestParams.graphic.imageType,
    -- value = commonSmoke.getPathToFileInStorage(requestParams.graphic.value)
  },
  secondaryGraphic = {
    imageType = requestParams.secondaryGraphic.imageType,
    -- value = commonSmoke.getPathToFileInStorage(requestParams.secondaryGraphic.value)
  }
}

local allParams = {
  requestParams = requestParams,
  responseUiParams = responseUiParams,
}

--[[ Local Functions ]]
local function Show(pParams, self)
  local cid = self.mobileSession1:SendRPC("Show", pParams.requestParams)
  pParams.responseUiParams.appID = commonSmoke.getHMIAppId()
  pParams.responseUiParams.graphic.value = commonSmoke.getPathToFileInStorage(pParams.requestParams.graphic.value)
  pParams.responseUiParams.secondaryGraphic.value = commonSmoke.getPathToFileInStorage(pParams.requestParams.secondaryGraphic.value)
  EXPECT_HMICALL("UI.Show", pParams.responseUiParams)
  :Do(function(_,data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", { })
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
runner.Step("Show Positive Case", Show, { allParams })

runner.Title("Postconditions")
runner.Step("Stop SDL", commonSmoke.postconditions)
