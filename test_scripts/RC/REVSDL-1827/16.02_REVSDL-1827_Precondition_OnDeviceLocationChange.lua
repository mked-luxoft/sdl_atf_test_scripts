local commonSteps = require("user_modules/shared_testcases/commonSteps")
commonSteps:DeleteLogsFileAndPolicyTable()

revsdl = require("user_modules/revsdl")

revsdl.AddUnknownFunctionIDs()
revsdl.SubscribeToRcInterface()
config.ValidateSchema = false
config.application1.registerAppInterfaceParams.appHMIType = { "REMOTE_CONTROL" }

Test = require('connecttest')
require('cardinalities')
local events = require('events')
local mobile_session = require('mobile_session')

--======================================REVSDL-1827========================================--
---------------------------------------------------------------------------------------------
--------------REVSDL-1827: Policies: "equipment" permissions must be checked-----------------
-------------------------- against location provided from HMI--------------------------------
---------------------------------------------------------------------------------------------
--=========================================================================================--

		-----------------------------------------------------------------------------------------
		-------------------------FOR BACK LEFT PASSENGER ZONE----------------------------------------

			--Begin Precondition.1. HMI sends notification RC.OnDeviceLocationChanged(<deviceID>) to RSDL (zone:BACK LEFT Passenger)
			--Description: HMI sends notification RC.OnDeviceLocationChanged(<deviceID>) to RSDL

				function Test:ChangedLocation_Left()
					--hmi side: HMI sends notification RC.OnDeviceLocationChanged(<deviceID>) to RSDL
					sleep(2)
					self.hmiConnection:SendNotification("RC.OnDeviceLocationChanged",
						{device = {name = "127.0.0.1", id = 1, isSDLAllowed = true},
							deviceLocation =
								{
									colspan = 2,
									row = 1,
									rowspan = 2,
									col = 0,
									levelspan = 1,
									level = 0
								}
						})

					--Send OnHMIStatus (NONE) to such app
					EXPECT_NOTIFICATION("OnHMIStatus",{ systemContext = "MAIN", hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE" })
				end
			--End Precondition.1
