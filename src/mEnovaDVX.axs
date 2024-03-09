MODULE_NAME='mEnovaDVX' 	(
                                dev vdvObject,
                                dev dvPort
                            )

(***********************************************************)
#DEFINE USING_NAV_MODULE_BASE_CALLBACKS
#DEFINE USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
#DEFINE USING_NAV_MODULE_BASE_PASSTHRU_EVENT_CALLBACK
#DEFINE USING_NAV_LOGIC_ENGINE_EVENT_CALLBACK
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.ArrayUtils.axi'
#include 'NAVFoundation.LogicEngine.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant integer MAX_LEVELS = 3
constant char LEVELS[][NAV_MAX_CHARS]	= { 'ALL',
                                            'VID',
                                            'AUD' }

constant char LEVEL_BYTES[][NAV_MAX_CHARS]	= { 'ALL',
                                                'VIDEO',
                                                'AUDIO' }

constant integer MAX_OUTPUTS = 16

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile integer output[MAX_LEVELS][MAX_OUTPUTS]
volatile integer outputSwitchPending[MAX_LEVELS][MAX_OUTPUTS]

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)
define_function Send(char payload[]) {
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_TO,
                                            dvPort,
                                            payload))

    send_command dvPort, "payload"
    wait 1 module.CommandBusy = false
}


define_function char[NAV_MAX_BUFFER] BuildSwitch(integer input, integer output, integer level) {
    return "'CL', LEVEL_BYTES[level], 'I', itoa(input), 'O', itoa(output)"
}


define_function Drive() {
    stack_var integer x
    stack_var integer z

    if (module.CommandBusy) {
        return
    }

    for (x = 1; x <= MAX_OUTPUTS; x++) {
        for (z = 1; z <= MAX_LEVELS; z++) {
            if (!outputSwitchPending[z][x] || module.CommandBusy) {
                continue
            }

            outputSwitchPending[z][x] = false
            module.CommandBusy = true

            Send(BuildSwitch(output[z][x], x, z))
        }
    }
}


#IF_DEFINED USING_NAV_LOGIC_ENGINE_EVENT_CALLBACK
define_function NAVLogicEngineEventCallback(_NAVLogicEngineEvent args) {
    switch (args.Name) {
        case NAV_LOGIC_ENGINE_EVENT_ACTION: {
            Drive()
        }
    }
}
#END_IF


#IF_DEFINED USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
define_function NAVModulePropertyEventCallback(_NAVModulePropertyEvent event) {
    if (event.Device != vdvObject) {
        return
    }
}
#END_IF


#IF_DEFINED USING_NAV_MODULE_BASE_PASSTHRU_EVENT_CALLBACK
define_function NAVModulePassthruEventCallback(_NAVModulePassthruEvent event) {
    if (event.Device != vdvObject) {
        return
    }

    Send(event.Payload)
}
#END_IF


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {

}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[dvPort] {
    online: {
        NAVLogicEngineStart()
    }
    command: {
        [vdvObject, DEVICE_COMMUNICATING] = true
        [vdvObject, DATA_INITIALIZED] = true

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM,
                                                data.device,
                                                data.text))
    }
}


data_event[vdvObject] {
    online: {
        NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_DESCRIPTION,Matrix Switcher'")
        NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_URL,www.amx.com'")
        NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_NAME,AMX'")
    }
    command: {
        stack_var _NAVSnapiMessage message

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM,
                                                data.device,
                                                data.text))

        NAVParseSnapiMessage(data.text, message)

        switch (message.Header) {
            case NAV_MODULE_EVENT_SWITCH: {
                stack_var integer level

                level = NAVFindInArrayString(LEVELS, message.Parameter[3])

                if (!level) { level = NAV_SWITCH_LEVEL_VID }

                output[level][atoi(message.Parameter[2])] = atoi(message.Parameter[1])
                outputSwitchPending[level][atoi(message.Parameter[2])] = true
            }
        }
    }
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
