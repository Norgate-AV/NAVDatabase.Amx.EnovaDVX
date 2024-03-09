# NAVDatabase.Amx.EnovaDVX

<!-- <div align="center">
 <img src="./" alt="logo" width="200" />
</div> -->

---

[![CI](https://github.com/Norgate-AV/NAVDatabase.Amx.EnovaDVX/actions/workflows/main.yml/badge.svg)](https://github.com/Norgate-AV/NAVDatabase.Amx.EnovaDVX/actions/workflows/main.yml)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)
[![Commitizen friendly](https://img.shields.io/badge/commitizen-friendly-brightgreen.svg)](http://commitizen.github.io/cz-cli/)
[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

AMX NetLinx module for Enova DVX Switchers.

## Contents :book:

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

-   [Installation :zap:](#installation-zap)
-   [Usage :rocket:](#usage-rocket)
-   [Team :soccer:](#team-soccer)
-   [Contributors :sparkles:](#contributors-sparkles)
-   [LICENSE :balance_scale:](#license-balance_scale)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Installation :zap:

This module can be installed using [Scoop](https://scoop.sh/).

```powershell
scoop bucket add norgateav-amx https://github.com/Norgate-AV/scoop-norgateav-amx
scoop install navdatabase-amx-enova-dvx
```

## Usage :rocket:

```netlinx
DEFINE_DEVICE

// The real device
dvEnovaDvx_Port_1               = 5002:1:0
dvEnovaDvx_Port_2               = 5002:2:0
dvEnovaDvx_Port_3               = 5002:3:0
dvEnovaDvx_Port_4               = 5002:4:0
dvEnovaDvx_Port_5               = 5002:5:0
dvEnovaDvx_Port_6               = 5002:6:0
dvEnovaDvx_Port_7               = 5002:7:0
dvEnovaDvx_Port_8               = 5002:8:0
dvEnovaDvx_Port_9               = 5002:9:0
dvEnovaDvx_Port_10              = 5002:10:0
dvEnovaDvx_Port_11              = 5002:11:0
dvEnovaDvx_Port_12              = 5002:12:0
dvEnovaDvx_Port_13              = 5002:13:0
dvEnovaDvx_Port_14              = 5002:14:0

// Virtual Devices
vdvEnovaDvx                     = 33201:1:0


DEFINE_CONSTANT

constant dev DVA_ENOVA_DVX[]    =   {
                                        dvEnovaDvx_Port_1,
                                        dvEnovaDvx_Port_2,
                                        dvEnovaDvx_Port_3,
                                        dvEnovaDvx_Port_4,
                                        dvEnovaDvx_Port_5,
                                        dvEnovaDvx_Port_6,
                                        dvEnovaDvx_Port_7,
                                        dvEnovaDvx_Port_8,
                                        dvEnovaDvx_Port_9,
                                        dvEnovaDvx_Port_10,
                                        dvEnovaDvx_Port_11,
                                        dvEnovaDvx_Port_12,
                                        dvEnovaDvx_Port_13,
                                        dvEnovaDvx_Port_14
                                    }


define_module 'mEnovaDVX' EnovaDVXComm(vdvEnovaDvx, DVA_ENOVA_DVX[1])


DEFINE_EVENT

data_event[DVA_ENOVA_DVX] {
    online: {
        // Wait until all devices are online
        if (data.device == DVA_ENOVA_DVX[length_array(DVA_ENOVA_DVX)]) {
            send_command vdvEnovaDvx, "'SWITCH-1,1,ALL'"        // Switch input 1 to output 1, video and audio

            send_command vdvEnovaDvx, "'SWITCH-1,2,VID'"        // Switch input 1 to output 2, video only

            send_command vdvEnovaDvx, "'SWITCH-1,3,AUD'"        // Switch input 1 to output 3, audio only
        }
    }
}

```

## Team :soccer:

This project is maintained by the following person(s) and a bunch of [awesome contributors](https://github.com/Norgate-AV/NAVDatabase.Amx.EnovaDVX/graphs/contributors).

<table>
  <tr>
    <td align="center"><a href="https://github.com/damienbutt"><img src="https://avatars.githubusercontent.com/damienbutt?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Damien Butt</b></sub></a><br /></td>
  </tr>
</table>

## Contributors :sparkles:

<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->

[![All Contributors](https://img.shields.io/badge/all_contributors-1-orange.svg?style=flat-square)](#contributors-)

<!-- ALL-CONTRIBUTORS-BADGE:END -->

Thanks go to these awesome people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://allcontributors.org) specification.
Contributions of any kind are welcome!

## LICENSE :balance_scale:

[MIT](LICENSE)
