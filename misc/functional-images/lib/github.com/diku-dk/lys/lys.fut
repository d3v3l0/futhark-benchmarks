-- | Lights, camera, action!

-- | For convenience, re-export the colour module.
open import "../../athas/matte/colour"

type key_event = #keydown | #keyup

module type lys = {
  type state

  -- | Initial state for a given window size.
  val init : (h: i32) -> (w: i32) -> state

  -- | Time-stepping the state.
  val step : (time_delta: f32) -> state -> state

  -- | The window was resized.
  val resize : (h: i32) -> (w: i32) -> state -> state

  -- | Something happened to the keyboard.
  val key : key_event -> i32 -> state -> state

  -- | Something happened to the mouse.
  val mouse : (mouse_state: i32) -> (x: i32) -> (y: i32) -> state -> state

  -- | The mouse wheel is turning.  Note that there can be multiple
  -- wheels; this is why the 'x' direction also makes sense.
  val wheel : (x: i32) -> (y: i32) -> state -> state

  -- | The function for rendering a screen image in row-major order
  -- (height by width).  The size of the array returned must match the
  -- last dimensions provided to the state (via `init`@term or
  -- `resize`@term).
  val render : state -> [][]argb.colour
}

-- | A dummy lys module that just produces a black rectangle and does
-- nothing in response to events.
module lys: lys = {
  type state = {h: i32, w: i32}
  let init h w = {h,w}
  let step _ s = s
  let resize h w _ = {h,w}
  let key _ _ s = s
  let mouse _ _ _ s = s
  let wheel _ _ s = s
  let render {h,w} = replicate w argb.black |> replicate h
}

module mk_lys (m: lys): lys = {
    open m
}

type keycode = i32

-- We should generate the following programmatically.

local let scancode (x: i32) = x | (1<<30)

-- The following values are taken from
-- https://wiki.libsdl.org/SDLKeycodeLookup

let SDLK_UNKNOWN: i32 = 0x00
let SDLK_BACKSPACE: i32 = 0x08
let SDLK_TAB: i32 = 0x09
let SDLK_RETURN: i32 = 0x0D
let SDLK_ESCAPE: i32 = 0x1B
let SDLK_SPACE: i32 = 0x20
let SDLK_EXCLAIM: i32 = 0x21
let SDLK_QUOTEDBL: i32 = 0x22
let SDLK_HASH: i32 = 0x23
let SDLK_DOLLAR: i32 = 0x24
let SDLK_PERCENT: i32 = 0x25
let SDLK_AMPERSAND: i32 = 0x26
let SDLK_QUOTE: i32 = 0x27
let SDLK_LEFTPAREN: i32 = 0x28
let SDLK_RIGHTPAREN: i32 = 0x29
let SDLK_ASTERISK: i32 = 0x2A
let SDLK_PLUS: i32 = 0x2B
let SDLK_COMMA: i32 = 0x2C
let SDLK_MINUS: i32 = 0x2D
let SDLK_PERIOD: i32 = 0x2E
let SDLK_SLASH: i32 = 0x2F
let SDLK_0: i32 = 0x30
let SDLK_1: i32 = 0x31
let SDLK_2: i32 = 0x32
let SDLK_3: i32 = 0x33
let SDLK_4: i32 = 0x34
let SDLK_5: i32 = 0x35
let SDLK_6: i32 = 0x36
let SDLK_7: i32 = 0x37
let SDLK_8: i32 = 0x38
let SDLK_9: i32 = 0x39
let SDLK_COLON: i32 = 0x3A
let SDLK_SEMICOLON: i32 = 0x3B
let SDLK_LESS: i32 = 0x3C
let SDLK_EQUALS: i32 = 0x3D
let SDLK_GREATER: i32 = 0x3E
let SDLK_QUESTION: i32 = 0x3F
let SDLK_AT: i32 = 0x40
let SDLK_LEFTBRACKET: i32 = 0x5B
let SDLK_BACKSLASH: i32 = 0x5C
let SDLK_RIGHTBRACKET: i32 = 0x5D
let SDLK_CARET: i32 = 0x5E
let SDLK_UNDERSCORE: i32 = 0x5F
let SDLK_BACKQUOTE: i32 = 0x60
let SDLK_a: i32 = 0x61
let SDLK_b: i32 = 0x62
let SDLK_c: i32 = 0x63
let SDLK_d: i32 = 0x64
let SDLK_e: i32 = 0x65
let SDLK_f: i32 = 0x66
let SDLK_g: i32 = 0x67
let SDLK_h: i32 = 0x68
let SDLK_i: i32 = 0x69
let SDLK_j: i32 = 0x6A
let SDLK_k: i32 = 0x6B
let SDLK_l: i32 = 0x6C
let SDLK_m: i32 = 0x6D
let SDLK_n: i32 = 0x6E
let SDLK_o: i32 = 0x6F
let SDLK_p: i32 = 0x70
let SDLK_q: i32 = 0x71
let SDLK_r: i32 = 0x72
let SDLK_s: i32 = 0x73
let SDLK_t: i32 = 0x74
let SDLK_u: i32 = 0x75
let SDLK_v: i32 = 0x76
let SDLK_w: i32 = 0x77
let SDLK_x: i32 = 0x78
let SDLK_y: i32 = 0x79
let SDLK_z: i32 = 0x7A
let SDLK_DELETE: i32 = 0x7F
let SDLK_CAPSLOCK: i32 = 0x40000039
let SDLK_F1: i32 = 0x4000003A
let SDLK_F2: i32 = 0x4000003B
let SDLK_F3: i32 = 0x4000003C
let SDLK_F4: i32 = 0x4000003D
let SDLK_F5: i32 = 0x4000003E
let SDLK_F6: i32 = 0x4000003F
let SDLK_F7: i32 = 0x40000040
let SDLK_F8: i32 = 0x40000041
let SDLK_F9: i32 = 0x40000042
let SDLK_F10: i32 = 0x40000043
let SDLK_F11: i32 = 0x40000044
let SDLK_F12: i32 = 0x40000045
let SDLK_PRINTSCREEN: i32 = 0x40000046
let SDLK_SCROLLLOCK: i32 = 0x40000047
let SDLK_PAUSE: i32 = 0x40000048
let SDLK_INSERT: i32 = 0x40000049
let SDLK_HOME: i32 = 0x4000004A
let SDLK_PAGEUP: i32 = 0x4000004B
let SDLK_END: i32 = 0x4000004D
let SDLK_PAGEDOWN: i32 = 0x4000004E
let SDLK_RIGHT: i32 = 0x4000004F
let SDLK_LEFT: i32 = 0x40000050
let SDLK_DOWN: i32 = 0x40000051
let SDLK_UP: i32 = 0x40000052
let SDLK_NUMLOCKCLEAR: i32 = 0x40000053
let SDLK_KP_DIVIDE: i32 = 0x40000054
let SDLK_KP_MULTIPLY: i32 = 0x40000055
let SDLK_KP_MINUS: i32 = 0x40000056
let SDLK_KP_PLUS: i32 = 0x40000057
let SDLK_KP_ENTER: i32 = 0x40000058
let SDLK_KP_1: i32 = 0x40000059
let SDLK_KP_2: i32 = 0x4000005A
let SDLK_KP_3: i32 = 0x4000005B
let SDLK_KP_4: i32 = 0x4000005C
let SDLK_KP_5: i32 = 0x4000005D
let SDLK_KP_6: i32 = 0x4000005E
let SDLK_KP_7: i32 = 0x4000005F
let SDLK_KP_8: i32 = 0x40000060
let SDLK_KP_9: i32 = 0x40000061
let SDLK_KP_0: i32 = 0x40000062
let SDLK_KP_PERIOD: i32 = 0x40000063
let SDLK_APPLICATION: i32 = 0x40000065
let SDLK_POWER: i32 = 0x40000066
let SDLK_KP_EQUALS: i32 = 0x40000067
let SDLK_F13: i32 = 0x40000068
let SDLK_F14: i32 = 0x40000069
let SDLK_F15: i32 = 0x4000006A
let SDLK_F16: i32 = 0x4000006B
let SDLK_F17: i32 = 0x4000006C
let SDLK_F18: i32 = 0x4000006D
let SDLK_F19: i32 = 0x4000006E
let SDLK_F20: i32 = 0x4000006F
let SDLK_F21: i32 = 0x40000070
let SDLK_F22: i32 = 0x40000071
let SDLK_F23: i32 = 0x40000072
let SDLK_F24: i32 = 0x40000073
let SDLK_EXECUTE: i32 = 0x40000074
let SDLK_HELP: i32 = 0x40000075
let SDLK_MENU: i32 = 0x40000076
let SDLK_SELECT: i32 = 0x40000077
let SDLK_STOP: i32 = 0x40000078
let SDLK_AGAIN: i32 = 0x40000079
let SDLK_UNDO: i32 = 0x4000007A
let SDLK_CUT: i32 = 0x4000007B
let SDLK_COPY: i32 = 0x4000007C
let SDLK_PASTE: i32 = 0x4000007D
let SDLK_FIND: i32 = 0x4000007E
let SDLK_MUTE: i32 = 0x4000007F
let SDLK_VOLUMEUP: i32 = 0x40000080
let SDLK_VOLUMEDOWN: i32 = 0x40000081
let SDLK_KP_COMMA: i32 = 0x40000085
let SDLK_KP_EQUALSAS400: i32 = 0x40000086
let SDLK_ALTERASE: i32 = 0x40000099
let SDLK_SYSREQ: i32 = 0x4000009A
let SDLK_CANCEL: i32 = 0x4000009B
let SDLK_CLEAR: i32 = 0x4000009C
let SDLK_PRIOR: i32 = 0x4000009D
let SDLK_RETURN2: i32 = 0x4000009E
let SDLK_SEPARATOR: i32 = 0x4000009F
let SDLK_OUT: i32 = 0x400000A0
let SDLK_OPER: i32 = 0x400000A1
let SDLK_CLEARAGAIN: i32 = 0x400000A2
let SDLK_CRSEL: i32 = 0x400000A3
let SDLK_EXSEL: i32 = 0x400000A4
let SDLK_KP_00: i32 = 0x400000B0
let SDLK_KP_000: i32 = 0x400000B1
let SDLK_THOUSANDSSEPARATOR: i32 = 0x400000B2
let SDLK_DECIMALSEPARATOR: i32 = 0x400000B3
let SDLK_CURRENCYUNIT: i32 = 0x400000B4
let SDLK_CURRENCYSUBUNIT: i32 = 0x400000B5
let SDLK_KP_LEFTPAREN: i32 = 0x400000B6
let SDLK_KP_RIGHTPAREN: i32 = 0x400000B7
let SDLK_KP_LEFTBRACE: i32 = 0x400000B8
let SDLK_KP_RIGHTBRACE: i32 = 0x400000B9
let SDLK_KP_TAB: i32 = 0x400000BA
let SDLK_KP_BACKSPACE: i32 = 0x400000BB
let SDLK_KP_A: i32 = 0x400000BC
let SDLK_KP_B: i32 = 0x400000BD
let SDLK_KP_C: i32 = 0x400000BE
let SDLK_KP_D: i32 = 0x400000BF
let SDLK_KP_E: i32 = 0x400000C0
let SDLK_KP_F: i32 = 0x400000C1
let SDLK_KP_XOR: i32 = 0x400000C2
let SDLK_KP_POWER: i32 = 0x400000C3
let SDLK_KP_PERCENT: i32 = 0x400000C4
let SDLK_KP_LESS: i32 = 0x400000C5
let SDLK_KP_GREATER: i32 = 0x400000C6
let SDLK_KP_AMPERSAND: i32 = 0x400000C7
let SDLK_KP_DBLAMPERSAND: i32 = 0x400000C8
let SDLK_KP_VERTICALBAR: i32 = 0x400000C9
let SDLK_KP_DBLVERTICALBAR: i32 = 0x400000CA
let SDLK_KP_COLON: i32 = 0x400000CB
let SDLK_KP_HASH: i32 = 0x400000CC
let SDLK_KP_SPACE: i32 = 0x400000CD
let SDLK_KP_AT: i32 = 0x400000CE
let SDLK_KP_EXCLAM: i32 = 0x400000CF
let SDLK_KP_MEMSTORE: i32 = 0x400000D0
let SDLK_KP_MEMRECALL: i32 = 0x400000D1
let SDLK_KP_MEMCLEAR: i32 = 0x400000D2
let SDLK_KP_MEMADD: i32 = 0x400000D3
let SDLK_KP_MEMSUBTRACT: i32 = 0x400000D4
let SDLK_KP_MEMMULTIPLY: i32 = 0x400000D5
let SDLK_KP_MEMDIVIDE: i32 = 0x400000D6
let SDLK_KP_PLUSMINUS: i32 = 0x400000D7
let SDLK_KP_CLEAR: i32 = 0x400000D8
let SDLK_KP_CLEARENTRY: i32 = 0x400000D9
let SDLK_KP_BINARY: i32 = 0x400000DA
let SDLK_KP_OCTAL: i32 = 0x400000DB
let SDLK_KP_DECIMAL: i32 = 0x400000DC
let SDLK_KP_HEXADECIMAL: i32 = 0x400000DD
let SDLK_LCTRL: i32 = 0x400000E0
let SDLK_LSHIFT: i32 = 0x400000E1
let SDLK_LALT: i32 = 0x400000E2
let SDLK_LGUI: i32 = 0x400000E3
let SDLK_RCTRL: i32 = 0x400000E4
let SDLK_RSHIFT: i32 = 0x400000E5
let SDLK_RALT: i32 = 0x400000E6
let SDLK_RGUI: i32 = 0x400000E7
let SDLK_MODE: i32 = 0x40000101
let SDLK_AUDIONEXT: i32 = 0x40000102
let SDLK_AUDIOPREV: i32 = 0x40000103
let SDLK_AUDIOSTOP: i32 = 0x40000104
let SDLK_AUDIOPLAY: i32 = 0x40000105
let SDLK_AUDIOMUTE: i32 = 0x40000106
let SDLK_MEDIASELECT: i32 = 0x40000107
let SDLK_WWW: i32 = 0x40000108
let SDLK_MAIL: i32 = 0x40000109
let SDLK_CALCULATOR: i32 = 0x4000010A
let SDLK_COMPUTER: i32 = 0x4000010B
let SDLK_AC_SEARCH: i32 = 0x4000010C
let SDLK_AC_HOME: i32 = 0x4000010D
let SDLK_AC_BACK: i32 = 0x4000010E
let SDLK_AC_FORWARD: i32 = 0x4000010F
let SDLK_AC_STOP: i32 = 0x40000110
let SDLK_AC_REFRESH: i32 = 0x40000111
let SDLK_AC_BOOKMARKS: i32 = 0x40000112
let SDLK_BRIGHTNESSDOWN: i32 = 0x40000113
let SDLK_BRIGHTNESSUP: i32 = 0x40000114
let SDLK_DISPLAYSWITCH: i32 = 0x40000115
let SDLK_KBDILLUMTOGGLE: i32 = 0x40000116
let SDLK_KBDILLUMDOWN: i32 = 0x40000117
let SDLK_KBDILLUMUP: i32 = 0x40000118
let SDLK_EJECT: i32 = 0x40000119
let SDLK_SLEEP: i32 = 0x4000011A
