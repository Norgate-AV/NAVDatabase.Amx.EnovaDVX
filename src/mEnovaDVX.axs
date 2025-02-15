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
#include 'NAVFoundation.Enova.axi'

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

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

struct _Context {
    integer output[NAV_ENOVA_SWITCH_LEVEL_COUNT][NAV_ENOVA_MAX_OUTPUTS]
    char outputSwitchPending[NAV_ENOVA_SWITCH_LEVEL_COUNT][NAV_ENOVA_MAX_OUTPUTS]

    integer portCount
    integer inputCount[NAV_ENOVA_SWITCH_LEVEL_COUNT]
    integer outputCount[NAV_ENOVA_SWITCH_LEVEL_COUNT]

    char initialized
}


(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile _Context context


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
    NAVCommand(dvPort, "payload")
    wait 1 module.CommandBusy = false
}


define_function Drive() {
    stack_var integer x
    stack_var integer z

    if (module.CommandBusy) {
        return
    }

    for (z = 1; z <= NAV_SWITCH_LEVEL_COUNT; z++) {
        for (x = 1; x <= context.outputCount[z]; x++) {
            if (!context.outputSwitchPending[z][x] || module.CommandBusy) {
                continue
            }

            context.outputSwitchPending[z][x] = false
            module.CommandBusy = true

            Send(NAVEnovaBuildSwitch(context.output[z][x], x, z))
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


define_function char GetDeviceIO() {
    stack_var _NAVEnovaPortInfo info

    if (!NAVEnovaGetPortInfo(info)) {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR, "'mEnovaDVX => Error determining device I/O. Is this an Enova device?'")
        return false
    }

    context.portCount = info.PortCount
    context.inputCount[NAV_SWITCH_LEVEL_VID] = info.InputCount.Video
    context.inputCount[NAV_SWITCH_LEVEL_AUD] = info.InputCount.Audio
    context.inputCount[NAV_SWITCH_LEVEL_ALL] = info.InputCount.Video
    context.outputCount[NAV_SWITCH_LEVEL_VID] = info.OutputCount.Video
    context.outputCount[NAV_SWITCH_LEVEL_AUD] = info.OutputCount.Audio
    context.outputCount[NAV_SWITCH_LEVEL_ALL] = info.OutputCount.Video

    return true
}


define_function Init() {
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'mEnovaDVX => Initializing...'")

    if (!GetDeviceIO()) {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR, "'mEnovaDVX => Initialization failed. Unable to get device I/O'")
        return
    }

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'mEnovaDVX => Device has ', itoa(context.portCount), ' ports'")
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'mEnovaDVX => Device has ', itoa(context.inputCount[1]), ' video inputs'")
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'mEnovaDVX => Device has ', itoa(context.inputCount[2]), ' audio inputs'")
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'mEnovaDVX => Device has ', itoa(context.outputCount[1]), ' video outputs'")
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'mEnovaDVX => Device has ', itoa(context.outputCount[2]), ' audio outputs'")

    set_length_array(context.output[NAV_SWITCH_LEVEL_VID], context.outputCount[NAV_SWITCH_LEVEL_VID])
    set_length_array(context.output[NAV_SWITCH_LEVEL_AUD], context.outputCount[NAV_SWITCH_LEVEL_AUD])
    set_length_array(context.output[NAV_SWITCH_LEVEL_ALL], context.outputCount[NAV_SWITCH_LEVEL_ALL])

    set_length_array(context.outputSwitchPending[NAV_SWITCH_LEVEL_VID], context.outputCount[NAV_SWITCH_LEVEL_VID])
    set_length_array(context.outputSwitchPending[NAV_SWITCH_LEVEL_AUD], context.outputCount[NAV_SWITCH_LEVEL_AUD])
    set_length_array(context.outputSwitchPending[NAV_SWITCH_LEVEL_ALL], context.outputCount[NAV_SWITCH_LEVEL_ALL])

    context.initialized = true
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'mEnovaDVX => Initialized'")

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'mEnovaDVX => Starting event loop'")
    NAVLogicEngineStart()
}


define_function ContextInit(_Context context) {
    NAVSetArrayInteger(context.output[NAV_SWITCH_LEVEL_VID], 0)
    NAVSetArrayInteger(context.output[NAV_SWITCH_LEVEL_AUD], 0)
    NAVSetArrayInteger(context.output[NAV_SWITCH_LEVEL_ALL], 0)

    NAVSetArrayChar(context.outputSwitchPending[NAV_SWITCH_LEVEL_VID], false)
    NAVSetArrayChar(context.outputSwitchPending[NAV_SWITCH_LEVEL_AUD], false)
    NAVSetArrayChar(context.outputSwitchPending[NAV_SWITCH_LEVEL_ALL], false)

    context.portCount = 0
    context.inputCount[NAV_SWITCH_LEVEL_VID] = 0
    context.inputCount[NAV_SWITCH_LEVEL_AUD] = 0
    context.inputCount[NAV_SWITCH_LEVEL_ALL] = 0
    context.outputCount[NAV_SWITCH_LEVEL_VID] = 0
    context.outputCount[NAV_SWITCH_LEVEL_AUD] = 0
    context.outputCount[NAV_SWITCH_LEVEL_ALL] = 0

    context.initialized = false
}


define_function ObjectSwitchCommandEvent(_NAVSnapiMessage message) {
    stack_var integer input
    stack_var integer output
    stack_var integer level

    if (message.ParameterCount < 2) {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR, "'mEnovaDVX => Invalid switch command. The SWITCH command must be followed by at least 2 arguments'")
        return
    }

    if (message.ParameterCount < 3) {
        NAVErrorLog(NAV_LOG_LEVEL_WARNING, "'mEnovaDVX => No switch level specified. Defaulting to ALL switch level'")
        level = NAV_SWITCH_LEVEL_ALL
    }
    else {
        level = NAVFindInArrayString(NAV_SWITCH_LEVELS, upper_string(message.Parameter[3]))

        if (!level) {
            NAVErrorLog(NAV_LOG_LEVEL_ERROR,
                        "'mEnovaDVX => Invalid switch command. The switch level is invalid. Valid levels are: ', NAVArrayJoinString(NAV_SWITCH_LEVELS, ', ')")
            NAVErrorLog(NAV_LOG_LEVEL_WARNING, "'mEnovaDVX => Defaulting to ALL switch level'")

            level = NAV_SWITCH_LEVEL_ALL
        }
    }

    input = atoi(message.Parameter[1])
    output = atoi(message.Parameter[2])

    if (input > context.inputCount[level]) {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR,
                    "'mEnovaDVX => Invalid switch command. Input number out of range.'")
        NAVErrorLog(NAV_LOG_LEVEL_ERROR,
                    "'mEnovaDVX => Valid input range for switch level ', NAVEnovaGetSwitchLevel(level), ' is 0-', itoa(context.inputCount[level])")

        return
    }

    if (output > context.outputCount[level]) {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR,
                    "'mEnovaDVX => Invalid switch command. Output number out of range.'")
        NAVErrorLog(NAV_LOG_LEVEL_ERROR,
                    "'mEnovaDVX => Valid output range for switch level ', NAVEnovaGetSwitchLevel(level), ' is 1-', itoa(context.outputCount[level])")

        return
    }

    context.output[level][output] = input
    context.outputSwitchPending[level][output] = true
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    ContextInit(context)
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[dvPort] {
    online: {
        Init()
    }
    command: {
        [vdvObject, DEVICE_COMMUNICATING] = true
        [vdvObject, DATA_INITIALIZED] = true
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

        NAVParseSnapiMessage(data.text, message)

        switch (message.Header) {
            case NAV_MODULE_EVENT_SWITCH: {
                ObjectSwitchCommandEvent(message)
            }
        }
    }
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
