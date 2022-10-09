{
    --------------------------------------------
    Filename: SX1276-FSK-RXDemo.spin
    Author: Jesse Burt
    Description: Receive demo of the SX1276 driver (FSK)
    Copyright (c) 2022
    Started Aug 26, 2021
    Updated Oct 9, 2022
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode        = cfg#_clkmode
    _xinfreq        = cfg#_xinfreq

' -- User-modifiable constants
    SER_BAUD        = 115_200
    LED             = cfg#LED1

    CS_PIN          = 0
    SCK_PIN         = 1
    MOSI_PIN        = 2
    MISO_PIN        = 3
    RESET_PIN       = 4                         ' optional (-1 to disable)
' --

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    time    : "time"
    sx1276  : "wireless.transceiver.sx1276"

VAR

    byte _buffer[256]

PUB main{} | sw[2], payld_len

    setup{}

    ser.position(0, 3)
    ser.strln(string("Receive mode"))
    sx1276.preset_fsk_rx_4k8{}                  ' FSK, 4800bps

' -- TX/RX settings
    sx1276.carrier_freq(902_300_000)            ' US 902.3MHz
    sx1276.payld_len(8)                         ' test packet size
    payld_len := sx1276.payld_len(-2)           ' read back from radio
    sx1276.fifo_int_thresh(payld_len-1)         ' trigger int at payld len-1
    sw[0] := $E7E7E7E7                          ' sync word bytes
    sw[1] := $E7E7E7E7
    sx1276.sync_word_len(8)                     ' 1..8
    sx1276.sync_word(sx1276#SW_WRITE, @sw)
    sx1276.payld_len_cfg(sx1276#PKTLEN_FIXED)   ' fixed-length payload
' --

' -- RX-specific settings
    sx1276.rx_mode{}

    ' change these if having difficulty with reception
    sx1276.lna_gain(0)                          ' -6, -12, -24, -26, -48 dB
                                                ' or LNA_AGC (0), LNA_HIGH (1)
    sx1276.rssi_int_thresh(-80)                 ' set rcvd signal level thresh
                                                '   considered a valid signal
                                                ' -127..0 (dBm)
' --

    repeat
        bytefill(@_buffer, 0, 256)              ' clear local RX buffer
        sx1276.rx_mode{}                        ' ready to receive

        ' wait for the radio to finish receiving
        repeat until sx1276.payld_rdy{}
        sx1276.rx_payld(payld_len, @_buffer)    ' get the data from the radio
        sx1276.idle{}                           ' go back to standby

        ' display the received payload on the terminal
        ser.position(0, 5)
        ser.hexdump(@_buffer, 0, 4, payld_len, 16 <# payld_len)

PUB setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))
    if sx1276.startx(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN, RESET_PIN)
        ser.str(string("SX1276 driver started"))
    else
        ser.strln(string("SX1276 driver failed to start - halting"))
        repeat

DAT
{
Copyright 2022 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

