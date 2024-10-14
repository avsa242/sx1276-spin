{
----------------------------------------------------------------------------------------------------
    Filename:       SX1276-FSK-TXDemo.spin
    Description:    Demo of the SX1276 driver
        * Transmit (FSK)
    Author:         Jesse Burt
    Started:        Aug 26, 2021
    Updated:        Oct 14, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

CON

    _clkmode    = xtal1+pll16x
    _xinfreq    = 5_000_000


OBJ

    time:   "time"
    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    radio:  "wireless.transceiver.sx1276" | CS=0, SCK=1, MOSI=2, MISO=3, RST=4
    str:    "string"


VAR

    byte _txbuff[radio.PAYLD_LEN_MAX]


PUB main() | count, sz, user_str, payld_len

    setup()

    ser.pos_xy(0, 3)
    ser.strln(@"Transmit mode")

    ' user-modifiable string to send over the air
    ' NOTE: the format should match the parameters in the sprintf() call below
    user_str := @"This is message # $%04.4x"


' -- TX/RX settings
    ' NOTE: These settings _must_ match the receiving node
    radio.preset_fsk_tx_4k8()                  ' FSK, 4800bps
    radio.carrier_freq(902_300_000)
    radio.syncwd_len(8)                        ' syncword length 1..8
    radio.set_syncwd( string($E7, $E7, $E7, $E7, $E7, $E7, $E7, $E7) )
    radio.payld_len_cfg(radio.PKTLEN_FIXED)   ' fixed-length payload
' --

' -- TX-specific settings
    { transmit power }
    radio.tx_sig_routing(radio.PABOOST)       ' RFO, PABOOST (board-dependent)
    radio.tx_pwr(5)                            ' -1..14 (RFO) 5..23 (PABOOST)

    { tell the radio to wait until the FIFO reaches the level set by }
    {   fifo_int_thresh() to actually transmit }
    radio.tx_start_cond(radio.TXSTART_FIFOLVL)
' --

    count := 0
    repeat
        ' clear the temporary string buffer and copy the user string with a counter to it
        bytefill(@_txbuff, 0, radio.PAYLD_LEN_MAX)
        str.sprintf1(@_txbuff, user_str, count++)

        ' get the final size of the string and tell the radio about it
        sz := strsize(@_txbuff)
        radio.payld_len(sz)
        radio.fifo_int_thresh(payld_len-1)      ' trigger int at payld len-1

        ' show what will be transmitted
        ser.pos_xy(0, 5)
        ser.printf1(@"Transmitting %d bytes:\n\r", sz)
        ser.hexdump(@_txbuff, 0, 4, sz, 16 <# sz)

        ' queue and transmit it
        radio.tx_payld(payld_len, @_txbuff)
        radio.tx_mode()

        ' wait until the radio is done
        repeat
        until radio.payld_sent()
        radio.idle()

        time.msleep(1000)                       ' wait in between packets
                                                ' (don't abuse the airwaves)


PUB setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( radio.start() )
        ser.strln(@"SX1276 driver started")
    else
        ser.strln(@"SX1276 driver failed to start - halting")
        repeat

DAT
{
Copyright 2024 Jesse Burt

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

