{
    --------------------------------------------
    Filename: SX1276-TXDemo.spin
    Author: Jesse Burt
    Description: Transmit demo of the SX1276 driver (LoRa mode)
    Copyright (c) 2021
    Started Dec 12, 2020
    Updated Aug 26, 2021
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
    sx1276    : "wireless.transceiver.sx1276.spi"
    int     : "string.integer"
    sf      : "string.format"

VAR

    byte _buffer[256]

PUB Main{} | count

    setup{}
    ser.position(0, 3)
    ser.strln(string("Transmit mode"))
' -- TX/RX settings
    sx1276.presetfsk_tx4k8{}

    sx1276.carrierfreq(902_300_000)
    sx1276.payloadlen(8)                        ' set to len of test pkts
    sx1276.fifothreshold(7)
' --

' -- TX-specific settings
    sx1276.txstartcondition(sx1276#TXSTART_FIFOLVL)
    sx1276.txsigrouting(sx1276#PABOOST)         ' RFO, PABOOST (board-depend.)
    sx1276.txpower(5)                           ' -1..14 (RFO) 5..23 (PABOOST)
' --

    repeat
        bytefill(@_buffer, 0, 256)              ' clear temp TX buffer
        ' payload is the string 'TEST' with hexadecimal counter after
        sf.sprintf1(@_buffer, string("TEST%s"), int.hex(count, 4))

        sx1276.txpayload(8, @_buffer)             ' queue the data
        sx1276.txmode

        ' wait until sending is complete
        repeat until sx1276.payloadsent{}
        sx1276.idle{}

        count++
        ser.position(0, 5)
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
        time.msleep(500)
        ser.stop{}
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
