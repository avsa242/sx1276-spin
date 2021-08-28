{
    --------------------------------------------
    Filename: SX1276-FSK-TXDemo.spin
    Author: Jesse Burt
    Description: Transmit demo of the SX1276 driver (FSK)
    Copyright (c) 2021
    Started Aug 26, 2021
    Updated Aug 28, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode        = cfg#_clkmode
    _xinfreq        = cfg#_xinfreq

' -- User-modifiable constants
    SER_BAUD        = 115_200
    LED             = cfg#LED1

    CS_PIN          = 5
    SCK_PIN         = 2
    MOSI_PIN        = 3
    MISO_PIN        = 4
    RESET_PIN       = 6                         ' use is recommended
                                                '   (-1 to disable)
' --

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    time    : "time"
    sx1276  : "wireless.transceiver.sx1276.spi"
    int     : "string.integer"
    sf      : "string.format"

VAR

    byte _buffer[256]

PUB Main{} | count, sw[2], payld_len

    setup{}
    ser.position(0, 3)
    ser.strln(string("Transmit mode"))
    sx1276.presetfsk_tx4k8{}                    ' FSK, 4800bps

' -- TX/RX settings
    sx1276.carrierfreq(902_300_000)
    sx1276.payloadlen(8)                        ' set to len of test pkts
    payld_len := sx1276.payloadlen(-2)          ' read it back, to verify
    sx1276.fifothreshold(payld_len-1)           ' trigger int at payld len-1

    sw[0] := $E7E7E7E7                          ' sync word bytes
    sw[1] := $E7E7E7E7
    sx1276.syncwordlen(8)                       ' 1..8
    sx1276.syncword(1, @sw)
    sx1276.payloadlencfg(sx1276#PKTLEN_FIXED)   ' fixed-length payload
' --

' -- TX-specific settings
    ' transmit power
    sx1276.txsigrouting(sx1276#PABOOST)         ' RFO, PABOOST (board-depend.)
    sx1276.txpower(5)                           ' -1..14 (RFO) 5..23 (PABOOST)

    ' tell the radio to wait until the FIFO reaches the level set by
    '   FIFOThreshold() to actually transmit
    sx1276.txstartcondition(sx1276#TXSTART_FIFOLVL)
' --

    count := 0
    repeat
        bytefill(@_buffer, 0, 256)              ' clear temp TX buffer
        ' payload is the string 'TEST' with hexadecimal counter after
        sf.sprintf1(@_buffer, string("TEST%s"), int.hex(count, 4))

        sx1276.txpayload(payld_len, @_buffer)   ' queue the data
        sx1276.txmode{}

        ' wait until sending is complete
        repeat until sx1276.payloadsent{}
        sx1276.idle{}

        count++
        ser.position(0, 7)
        ser.str(string("Sending: "))
        ser.strln(@_buffer)

        time.msleep(5000)                       ' wait in between packets
                                                ' (don't abuse the airwaves)

PUB Setup{}

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
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
