---------------------------------------------------------------------------------------------------
-- User story: https://github.com/smartdevicelink/sdl_requirements/issues/27
-- Use case: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/embedded_navi/Unsubscribe_from_Destination_and_Waypoints.md
-- Item: Use Case 1:Exception 3
--
-- Requirement summary:
-- [UnsubscribeWayPoints] As a mobile app I want to be able to unsubscribes from getting notifications
-- about any changes to the destination or waypoints.
--
-- Description:
-- In case:
-- 1) mobile application sent valid and allowed by Policies UnsubscribeWayPoints_request to SDL
-- 2) and Navigation interface is not available on HMI
--
-- SDL must:
-- 1) respond UNSUPPORTED_RESOURCE, success:false to mobile application without transferring this request to HMI

---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/Navigation/commonNavigation')
local hmi_values = require('user_modules/hmi_values')
local commonTestCases = require('user_modules/shared_testcases/commonTestCases')

--[[ Local Functions ]]
local function disableNavigationInterface()
  local params = hmi_values.getDefaultHMITable()
  params.Navigation.IsReady.params.available = false
  return params
end

local function unsubscribeWayPoints(self)
  local cid = self.mobileSession1:SendRPC("UnsubscribeWayPoints", {})
  EXPECT_HMICALL("Navigation.UnsubscribeWayPoints"):Times(0)
  self.mobileSession1:ExpectResponse(cid, { success = false, resultCode = "UNSUPPORTED_RESOURCE" })
  commonTestCases:DelayedExp(common.timeout)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("RAI, PTU", common.registerAppWithPTU)
runner.Step("Activate App", common.activateApp)
runner.Step("SubscribeWayPoints", common.subscribeWayPoints)
runner.Step("Is Subscribed", common.isSubscribed)

runner.Title("Test")
runner.Step("IGNITION_OFF", common.IGNITION_OFF)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start, { disableNavigationInterface() })
runner.Step("RAI", common.registerAppWithTheSameHashId)
runner.Step("Activate App", common.activateApp)
runner.Step("UnsubscribeWayPoints", unsubscribeWayPoints)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)