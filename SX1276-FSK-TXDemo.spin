{
    --------------------------------------------
    Filename: SX1276-FSK-TXDemo.spin
    Author: Jesse Burt
    Description: Transmit demo of the SX1276 driver (FSK)
    Copyright (c) 2022
    Started Aug 26, 2021
    Updated Nov 13, 2022
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

    cfg   : "boardcfg.flip"
    ser   : "com.serial.terminal.ansi"
    time  : "time"
    sx1276: "wireless.transceiver.sx1276"
    str   : "string"

VAR

    byte _buffer[256]

PUB main{} | count, payld_len

    setup{}
    ser.pos_xy(0, 3)
    ser.strln(string("Transmit mode"))
    sx1276.preset_fsk_tx_4k8{}                  ' FSK, 4800bps

' -- TX/RX settings
    sx1276.carrier_freq(902_300_000)
    sx1276.payld_len(8)                         ' set to len of test pkts
    payld_len := sx1276.payld_len(-2)           ' read it back, to verify
    sx1276.fifo_int_thresh(payld_len-1)         ' trigger int at payld len-1

    sx1276.syncwd_len(8)                        ' syncword length 1..8
    sx1276.set_syncwd(string($E7, $E7, $E7, $E7, $E7, $E7, $E7, $E7))
    sx1276.payld_len_cfg(sx1276#PKTLEN_FIXED)   ' fixed-length payload
' --

' -- TX-specific settings
    { transmit power }
    sx1276.tx_sig_routing(sx1276#PABOOST)       ' RFO, PABOOST (board-dependent)
    sx1276.tx_pwr(5)                            ' -1..14 (RFO) 5..23 (PABOOST)

    { tell the radio to wait until the FIFO reaches the level set by }
    {   fifo_int_thresh() to actually transmit }
    sx1276.tx_start_cond(sx1276#TXSTART_FIFOLVL)
' --

    count := 0
    repeat
        bytefill(@_buffer, 0, 256)              ' clear temp TX buffer
        { payload is the string 'TEST' with hexadecimal counter after }
        str.sprintf1(@_buffer, string("TEST%04.4x"), count)

        sx1276.tx_payld(payld_len, @_buffer)    ' queue the data
        sx1276.tx_mode{}

        { wait until sending is complete }
        repeat until sx1276.payld_sent{}
        sx1276.idle{}

        count++
        ser.pos_xy(0, 7)
        ser.str(string("Sending: "))
        ser.strln(@_buffer)

        time.msleep(5000)                       ' wait in between packets
                                                ' (don't abuse the airwaves)

PUB setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))
    if sx1276.startx(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN, RESET_PIN)
        ser.strln(string("SX1276 driver started"))
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

