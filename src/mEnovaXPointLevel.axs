MODULE_NAME='mEnovaXPointLevel'	(
                                    dev vdvObject
                                )

(***********************************************************)
#DEFINE USING_NAV_MODULE_BASE_CALLBACKS
#DEFINE USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
#DEFINE USING_NAV_ENOVA_AUDIO_XPOINT_EVENT_CALLBACK
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.Math.axi'
#include 'NAVFoundation.TimelineUtils.axi'
#include 'NAVFoundation.Enova.axi'
#include 'NAVFoundation.EnovaEvents.axi'

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

constant long TL_LEVEL_RAMP = 1

constant long TL_LEVEL_RAMP_INTERVAL[] = { 200 }

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

struct _Context {
    integer input
    char inputSet

    integer output
    char outputSet

    sinteger level
    char mute

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
    NAVCommand(5002:1:0, payload)
}


#IF_DEFINED USING_NAV_ENOVA_AUDIO_XPOINT_EVENT_CALLBACK
define_function NAVEnovaAudioXPointEventCallback(_NAVEnovaAudioXpointEventArgs args) {
    if (!ParamsInitialized()) {
        return
    }

    if (args.Input != context.input || args.Output != context.output) {
        return
    }

    context.initialized = true

    if (args.Level == NAV_ENOVA_AUDIO_XPOINT_LEVEL_MUTE) {
        context.mute = true
        UpdateFeedback()
        return
    }

    context.mute = false
    UpdateFeedback()
    context.level = args.Level

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                "'mEnovaXPointLevel [', NAVDeviceToString(vdvObject), '] => ',
                                        NAVEnovaGetXPointInput(context.input), '->', NAVEnovaGetXPointOutput(context.output), ': ', itoa(context.level)")

    select {
        active (context.level > NAV_ENOVA_AUDIO_XPOINT_LEVEL_MAX): {
            Send(NAVEnovaBuildSetXpointLevel(context.input, context.output, NAV_ENOVA_AUDIO_XPOINT_LEVEL_MAX))
            Send(NAVEnovaBuildGetXpointLevel(context.input, context.output))
        }
        active (context.level < NAV_ENOVA_AUDIO_XPOINT_LEVEL_MIN): {
            Send(NAVEnovaBuildSetXpointLevel(context.input, context.output, NAV_ENOVA_AUDIO_XPOINT_LEVEL_MIN))
            Send(NAVEnovaBuildGetXpointLevel(context.input, context.output))
        }
        active (true): {
            send_level vdvObject, VOL_LVL, NAVScaleValue(context.level - NAV_ENOVA_AUDIO_XPOINT_LEVEL_MIN,
                                                                    (NAV_ENOVA_AUDIO_XPOINT_LEVEL_MAX - NAV_ENOVA_AUDIO_XPOINT_LEVEL_MIN),
                                                                    255,
                                                                    0)

            send_string vdvObject, "'VOLUME-ABS,', itoa(context.level)"
        }
    }
}
#END_IF


define_function ContextInit(_Context context) {
    context.input = 0
    context.inputSet = false

    context.output = 0
    context.outputSet = false

    context.level = 0
    context.mute = false
    UpdateFeedback()

    context.initialized = false
}


#IF_DEFINED USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
define_function NAVModulePropertyEventCallback(_NAVModulePropertyEvent event) {
    if (event.Device != vdvObject) {
        return
    }

    switch (event.Name) {
        case 'INPUT': {
            context.input = atoi(NAVTrimString(event.Args[1]))
            context.inputSet = true

            Init()
        }
        case 'OUTPUT': {
            context.output = atoi(NAVTrimString(event.Args[1]))
            context.outputSet = true

            Init()
        }
    }
}
#END_IF


define_function char ParamsInitialized() {
    return (context.inputSet &&
            context.outputSet &&
            context.input > 0 &&
            context.output > 0)
}


define_function char IsInitialized() {
    return (ParamsInitialized() && context.initialized)
}


define_function SetLevel(sinteger level) {
    if (!ParamsInitialized()) {
        return
    }

    if (level > NAV_ENOVA_AUDIO_XPOINT_LEVEL_MAX) {
        level = NAV_ENOVA_AUDIO_XPOINT_LEVEL_MAX
    }

    if (level < NAV_ENOVA_AUDIO_XPOINT_LEVEL_MUTE) {
        level = NAV_ENOVA_AUDIO_XPOINT_LEVEL_MUTE
    }

    Send(NAVEnovaBuildSetXpointLevel(context.input, context.output, level))
    Send(NAVEnovaBuildGetXpointLevel(context.input, context.output))
}


define_function SetMute(char state) {
    if (!ParamsInitialized()) {
        return
    }

    if (state) {
        SetLevel(NAV_ENOVA_AUDIO_XPOINT_LEVEL_MUTE)
    }
    else {
        SetLevel(context.level)
    }
}


define_function Init() {
    if (IsInitialized()) {
        return
    }

    if (!ParamsInitialized()) {
        return
    }

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                "'mEnovaXPointLevel [', NAVDeviceToString(vdvObject), '] => ',
                                        NAVEnovaGetXPointInput(context.input), '->', NAVEnovaGetXPointOutput(context.output), ': Initializing'")

    Send(NAVEnovaBuildGetXpointLevel(context.input, context.output))
}


define_function IncrementLevel(integer direction) {
    switch (direction) {
        case VOL_UP: {
            if (context.level == NAV_ENOVA_AUDIO_XPOINT_LEVEL_MAX) {
                return
            }

            SetLevel(context.level + 1)
        }
        case VOL_DN: {
            if (context.level == NAV_ENOVA_AUDIO_XPOINT_LEVEL_MIN) {
                return
            }

            SetLevel(context.level - 1)
        }
    }
}


define_function RampLevel() {
    select {
        active ([vdvObject, VOL_UP]): {
            IncrementLevel(VOL_UP)
        }
        active ([vdvObject, VOL_DN]): {
            IncrementLevel(VOL_DN)
        }
    }
}


define_function ObjectChannelEvent(tchannel channel) {
    switch (channel.channel) {
        case VOL_UP:
        case VOL_DN: {
            if (!IsInitialized()) {
                if (!ParamsInitialized()) {
                    NAVErrorLog(NAV_LOG_LEVEL_WARNING, "'mEnovaXPointLevel [', NAVDeviceToString(vdvObject), '] => Input/Output not set'")
                    return
                }

                NAVErrorLog(NAV_LOG_LEVEL_WARNING,
                            "'mEnovaXPointLevel [', NAVDeviceToString(vdvObject), '] => ',
                                                    NAVEnovaGetXPointInput(context.input), '->', NAVEnovaGetXPointOutput(context.output), ': Not initialized'")

                Init()

                return
            }

            IncrementLevel(channel.channel)

            NAVTimelineStart(TL_LEVEL_RAMP, TL_LEVEL_RAMP_INTERVAL, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
        }
    }
}


define_function UpdateFeedback() {
    [vdvObject, VOL_MUTE_FB] = (context.mute)
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

data_event[5002:1:0] {
    online: {
        Init()
    }
    offline: {
        context.initialized = false
    }
}


data_event[vdvObject] {
    command: {
        stack_var _NAVSnapiMessage message

        NAVParseSnapiMessage(data.text, message)

        switch (message.Header) {
            case 'VOLUME': {
                if (!length_array(message.Parameter[1])) {
                    break
                }

                switch (message.Parameter[1]) {
                    case 'ABS': {
                        stack_var sinteger level

                        if (!length_array(message.Parameter[2])) {
                            break
                        }

                        level = atoi(message.Parameter[2])

                        SetLevel(level)
                    }
                    default: {
                        stack_var sinteger level

                        level = NAVScaleValue(atoi(message.Parameter[1]),
                                                255,
                                                (NAV_ENOVA_AUDIO_XPOINT_LEVEL_MAX - NAV_ENOVA_AUDIO_XPOINT_LEVEL_MIN),
                                                0)

                        SetLevel(level)
                    }
                }
            }
            case 'MUTE': {
                if (!length_array(message.Parameter[1])) {
                    break
                }

                switch (message.Parameter[1]) {
                    case 'ON': {
                        SetMute(true)
                    }
                    case 'OFF': {
                        SetMute(false)
                    }
                }
            }
        }
    }
}


channel_event[vdvObject, 0] {
    on: {
        ObjectChannelEvent(channel)
    }
    off: {
        NAVTimelineStop(TL_LEVEL_RAMP)
    }
}


timeline_event[TL_LEVEL_RAMP] {
    RampLevel()
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
