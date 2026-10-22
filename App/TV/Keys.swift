/// Tastencodes der Panasonic-VIERA-Netzwerksteuerung (NRC, Modelle ab 2011, z. B. WT50).
enum VieraKey: String, CaseIterable {
    case power = "NRC_POWER-ONOFF"
    case input = "NRC_CHG_INPUT-ONOFF"
    case tv = "NRC_TV-ONOFF"
    case connect = "NRC_INTERNET-ONOFF"
    case tools = "NRC_VTOOLS-ONOFF"
    case vieraLink = "NRC_VIERA_LINK-ONOFF"

    case menu = "NRC_MENU-ONOFF"
    case option = "NRC_SUBMENU-ONOFF"
    case info = "NRC_INFO-ONOFF"
    case guide = "NRC_EPG-ONOFF"
    case back = "NRC_RETURN-ONOFF"
    case exit = "NRC_CANCEL-ONOFF"

    case up = "NRC_UP-ONOFF", down = "NRC_DOWN-ONOFF", left = "NRC_LEFT-ONOFF", right = "NRC_RIGHT-ONOFF"
    case enter = "NRC_ENTER-ONOFF"

    case volumeUp = "NRC_VOLUP-ONOFF", volumeDown = "NRC_VOLDOWN-ONOFF", mute = "NRC_MUTE-ONOFF"
    case channelUp = "NRC_CH_UP-ONOFF", channelDown = "NRC_CH_DOWN-ONOFF", lastView = "NRC_R_TUNE-ONOFF"

    case red = "NRC_RED-ONOFF", green = "NRC_GREEN-ONOFF", yellow = "NRC_YELLOW-ONOFF", blue = "NRC_BLUE-ONOFF"

    case d0 = "NRC_D0-ONOFF", d1 = "NRC_D1-ONOFF", d2 = "NRC_D2-ONOFF", d3 = "NRC_D3-ONOFF", d4 = "NRC_D4-ONOFF"
    case d5 = "NRC_D5-ONOFF", d6 = "NRC_D6-ONOFF", d7 = "NRC_D7-ONOFF", d8 = "NRC_D8-ONOFF", d9 = "NRC_D9-ONOFF"

    case text = "NRC_TEXT-ONOFF", subtitles = "NRC_STTL-ONOFF"

    case play = "NRC_PLAY-ONOFF", pause = "NRC_PAUSE-ONOFF", stop = "NRC_STOP-ONOFF", record = "NRC_REC-ONOFF"
    case rewind = "NRC_REW-ONOFF", fastForward = "NRC_FF-ONOFF"
    case previous = "NRC_SKIP_PREV-ONOFF", next = "NRC_SKIP_NEXT-ONOFF"

    case threeD = "NRC_3D-ONOFF", aspect = "NRC_ASPECT-ONOFF", offTimer = "NRC_OFFTIMER-ONOFF", sdCard = "NRC_SD_CARD-ONOFF"

    static func digit(_ n: Int) -> VieraKey {
        [.d0, .d1, .d2, .d3, .d4, .d5, .d6, .d7, .d8, .d9][n]
    }
}
