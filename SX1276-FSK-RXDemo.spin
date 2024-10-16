{
----------------------------------------------------------------------------------------------------
    Filename:       SX1276-FSK-RXDemo.spin
    Description:    Demo of the SX1276 driver
        * Receive (FSK)
    Author:         Jesse Burt
    Started:        Aug 26, 2021
    Updated:        Oct 14, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

CON

    _clkmode        = xtal1+pll16x
    _xinfreq        = 5_000_000


OBJ

    time:   "time"
    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    radio:  "wireless.transceiver.sx1276" | CS=0, SCK=1, MOSI=2, MISO=3, RST=4


VAR

    byte _buffer[radio.PAYLD_LEN_MAX]


PUB main() | sw[2], payld_len

    setup()

    ser.pos_xy(0, 3)
    ser.strln(@"Receive mode")

' -- TX/RX settings
    ' NOTE: These settings _must_ match the transmitting node
    radio.preset_fsk_rx_4k8()                   ' preset settings: FSK, 4800bps
    radio.carrier_freq(902_300_000)             ' US 902.3MHz
    radio.payld_len(8)                          ' set to length of test pkts
    radio.payld_len_cfg(radio.PKTLEN_FIXED)     ' fixed-length payload
    payld_len := radio.payld_len()              ' read back from radio
    radio.fifo_int_thresh(payld_len-1)          ' trigger int at payld len-1
    radio.syncwd_len(8)                         ' syncword length 1..8
    radio.set_syncwd( string($E7, $E7, $E7, $E7, $E7, $E7, $E7, $E7) )
' --

' -- RX-specific settings
    radio.rx_mode()

    ' change these if having difficulty with reception
    radio.lna_gain(0)                           ' -6, -12, -24, -26, -48 dB
                                                ' or LNA_AGC (0), LNA_HIGH (1)
    radio.rssi_int_thresh(-80)                  ' set rcvd signal level thresh
                                                '   considered a valid signal
                                                ' -127..0 (dBm)
' --

    repeat
        ' clear the temporary receive buffer and set up the radio for reception
        bytefill(@_buffer, 0, radio.PAYLD_LEN_MAX)
        radio.rx_mode()

        ' wait for the radio to finish receiving
        repeat
        until radio.payld_rdy()
        radio.rx_payld(payld_len, @_buffer)     ' get the data from the radio
        radio.idle()                            ' go back to standby

        ' display the received payload on the terminal
        ser.pos_xy(0, 5)
        ser.printf1(@"Received %d bytes:\n\r", payld_len)
        ser.hexdump(@_buffer, 0, 4, payld_len, 16 <# payld_len)


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

