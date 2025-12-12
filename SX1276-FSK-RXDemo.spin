{
----------------------------------------------------------------------------------------------------
    Filename:       SX1276-FSK-RXDemo.spin
    Description:    Demo of the SX1276 driver
        * Receive (FSK)
    Author:         Jesse Burt
    Started:        Aug 26, 2021
    Updated:        Dec 12, 2025
    Copyright (c) 2025 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

CON

    _clkmode    = xtal1+pll16x
    _xinfreq    = 5_000_000


OBJ

    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    radio:  "wireless.transceiver.sx1276" | CS=0, SCK=1, MOSI=2, MISO=3, RST=4
    time:   "time"


VAR

    byte _buffer[radio.PAYLD_LEN_MAX]


DAT

    ' define up to an 8 byte syncword (no zeroes allowed; a zero will be interpreted as the end)
    ' this MUST match the transmitter
    syncword    byte $2d, $d4, $e7, $c6, 0


PUB main() | payld_len, rssi, sl, w, int

    setup()

    ser.pos_xy(0, 3)
    ser.strln(@"Receive mode")
    radio.preset_fsk_rx_4k8_fixedlen()          ' preset: FSK, 4800bps, fixed-length payloads


' -- Try changing these settings if having difficulty receiving data
    radio.carrier_freq(902_300_000)             ' receive frequency (MUST match transmitter)
'    radio.lna_gain(0)                           ' -6, -12, -24, -26, -48 dB
                                                ' or LNA_AGC (0), LNA_HIGH (1)
'    radio.afc_auto_ena(true)                    ' enable automatic frequency correction
' --

    radio.syncwd_len(strsize(@syncword) )       ' get the length of the syncword
    radio.set_syncwd(@syncword)                 '   and set it

    ser.printf(@"Carrier freq: %dHz  syncword: ", radio.carrier_freq() )
    sl := radio.syncwd_len()
    repeat w from 0 to sl-1
        ser.printf(@"%02.2x ", syncword[w])
    ser.newline()

    payld_len := 8                              ' set length of payload (MUST match transmitter)
    radio.payld_len(payld_len)
    radio.fifo_int_thresh(payld_len)            ' trigger int at payld len
    radio.rx_mode()

    repeat
        repeat
            rssi := radio.rssi()
            int := radio.interrupt()
        until ( int & radio.INT_PAYLDREADY )    ' wait for payload to be ready (RX and good CRC)

        ser.printf(@"rssi: %4.4d  len: %d  ", rssi, payld_len)

        ' read the payload and display it on the terminal
        bytefill(@_buffer, 0, radio.PAYLD_LEN_MAX)
        radio.rx_payld(payld_len, @_buffer)     ' get the data from the radio
        ser.hexdump(@_buffer, 0, 2, payld_len, 16 <# payld_len)


PUB setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( radio.start() )
        ser.str(@"SX1276 driver started")
    else
        ser.strln(@"SX1276 driver failed to start - halting")
        repeat


DAT
{
Copyright 2025 Jesse Burt

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

