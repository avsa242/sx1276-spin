{
----------------------------------------------------------------------------------------------------
    Filename:       wireless.transceiver.sx1276.spin
    Description:    Driver for the SEMTECH SX1276 FSK/OOK transceiver
    Author:         Jesse Burt
    Started:        Oct 6, 2019
    Updated:        Oct 14, 2025
    Copyright (c) 2025 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

CON

    { default I/O settings; these can be overridden in the parent object }
    ' SPI
    CS                      = 0
    SCK                     = 1
    MOSI                    = 2
    MISO                    = 3
    SPI_FREQ                = 1_000_000
    RST                     = 4

    ' limits
    PAYLD_LEN_MAX           = 64


    ' oscillator
    FXOSC                   = 32_000_000
    TWO_19                  = 1 << 19
    TWO_24                  = 1 << 24
    FPSCALE                 = 10_000_000        ' scaling factor used in math
    FSTEP                   = 61_0351562        ' (FXOSC / TWO_19) * FPSCALE

    ' Modulation modes
    FSK                     = 0
    OOK                     = 1

    ' Device modes
    SLEEPMODE               = %000
    STDBY                   = %001
    FSTX                    = %010
    TX                      = %011
    FSRX                    = %100
    RXCONT                  = %101
    RXSINGLE                = %110
    CAD                     = %111

    ' Transmit modes
    TXMODE_NORMAL           = 0
    TXMODE_CONT             = 1

    ' DIO function mapping
    DIO0_RXDONE             = %00
    DIO0_TXDONE             = %01
    DIO0_CADDONE            = %10

    DIO1_RXTIMEOUT          = %00
    DIO1_FHSSCHANGECHANNEL  = %01
    DIO1_CADDETECTED        = %10

    DIO2_FHSSCHANGECHANNEL  = %00
    DIO2_SYNCADDRESS        = %11

    DIO3_CADDONE            = %00
    DIO3_VALIDHDR           = %01
    DIO3_PAYLDCRCERROR      = %10

    DIO4_CADDETECTED        = %00
    DIO4_PLLLOCK            = %01

    DIO5_MODEREADY          = %00
    DIO5_CLKOUT             = %01

    ' Clock output modes
    CLKOUT_RC               = 6
    CLKOUT_OFF              = 7

    ' Power Amplifier output pin selection
    RFO                     = 0
    PABOOST                 = 1 << core.PASELECT

    ' Gaussian modulation shaping filters
    BT_NONE                 = 0
    BT_1_0                  = 1
    BT_0_5                  = 2
    BT_0_3                  = 3

    ' Interrupt flags
    INT_MODEREADY           = 1 << 15           ' opmode() ready
    INT_RXREADY             = 1 << 14           ' receive ready
    INT_TXREADY             = 1 << 13           ' transmit ready
    INT_PLLLOCK             = 1 << 12           ' PLL is locked
    INT_RSSITHRESH          = 1 << 11           ' rssi() above rssi_int_thresh()
    INT_TIMEOUT             = 1 << 10           ' timeout occurred
    INT_PREAMBLEOK          = 1 << 9            ' preamble OK
    INT_SYNCWORDOK          = 1 << 8            ' syncword OK
    INT_FIFOFULL            = 1 << 7            ' FIFO is full
    INT_FIFOEMPTY           = 1 << 6            ' FIFO is empty
    INT_FIFOTHRESH          = 1 << 5            ' FIFO is above set threshold
    INT_FIFOOVERRN          = 1 << 4            ' FIFO has overrun
    INT_PACKETSENT          = 1 << 3            ' packet sent (TX)
    INT_PAYLDREADY          = 1 << 2            ' payload ready (RX)
    INT_CRCOK               = 1 << 1            ' CRC of payload is OK
    INT_BATTVOLTLO          = 1                 ' battery voltage low

    ' Payload length mode
    PKTLEN_FIXED            = 0
    PKTLEN_VAR              = 1

    ' Sync word read/write operation
    SW_READ                 = 0
    SW_WRITE                = 1

    ' DC-free encoding/decoding
    DCFREE_NONE             = %00
    DCFREE_MANCH            = %01
    DCFREE_WHITE            = %10

    ' Address matching
    ADDRCHK_NONE            = %00
    ADDRCHK_CHK_NO_BCAST    = %01
    ADDRCHK_CHK_BCAST       = %10

    ' Data modes
    DATAMODE_CONT           = 0
    DATAMODE_PKT            = 1

    ' Transmit start conditions
    TXSTART_FIFOLVL         = 0
    TXSTART_FIFONOTEMPTY    = 1


VAR

    long _CS, _RESET
    long _txsig_routing


OBJ

    core:   "core.con.sx1276"                   ' HW-specific constants
    spi:    "com.spi.1mhz"                      ' SPI engine
    time:   "time"                              ' timekeeping methpds
    u64:    "math.unsigned64"                   ' unsigned 64-bit math routines


PUB null()
' This is not a top-level object


PUB start(): status
' Start the driver using default I/O settings
    return startx(CS, SCK, MOSI, MISO, RST)


PUB startx(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN, RESET_PIN): status
' Start the driver with custom I/O settings
'   CS_PIN:     Chip Select (0..31)
'   SCK_PIN:    Serial Clock (0..31)
'   MOSI_PIN:   Master-Out Slave-In (0..31)
'   MISO_PIN:   Master-In Slave-Out (0..31)
'   RESET_PIN:  Reset (0..31)
'   Returns:
'       cog ID+1 of SPI engine on success (= calling cog ID+1, if the bytecode SPI engine is used)
'       0 on failure
    if ( lookdown(CS_PIN: 0..31) and lookdown(SCK_PIN: 0..31) and lookdown(MOSI_PIN: 0..31) ...
            and lookdown(MISO_PIN: 0..31) )
        if ( status := spi.init(SCK_PIN, MOSI_PIN, MISO_PIN, core.SPI_MODE) )
            time.usleep(core.T_POR)
            _CS := CS_PIN
            _RESET := RESET_PIN
            outa[_CS] := 1
            dira[_CS] := 1
            reset()
            if ( lookdown(dev_id(): $11, $12) )
                return
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE


PUB stop()
' Stop the driver
    spi.deinit()
    longfill(@_CS, 0, 3)


PUB defaults()
' Set factory defaults
    reset()


PUB preset_fsk_tx_4k8()
' TX FSK, 4.8kbps
    reset()
    modulation(FSK)


PUB preset_fsk_rx_4k8()
' RX FSK, 4.8kbps
    reset()
    modulation(FSK)


PUB addr_check(md=-2): c
' Enable address checking/matching/filtering
'   Valid values:
'       ADDRCHK_NONE (%00): No address check
'       ADDRCHK_CHK_NO_BCAST (%01): Check address, but ignore broadcast addresses
'       ADDRCHK_CHK_00_BCAST (%10): Check address, and also respond to broadcast address
'   Any other value polls the chip and returns the current setting
    c := readreg(core.PKTCFG1)
    case md
        ADDRCHK_NONE, ADDRCHK_CHK_NO_BCAST, ADDRCHK_CHK_BCAST:
            md <<= core.ADDRFILT
            md := ((c & core.ADDRFILT_MASK) | md)
            writereg(core.PKTCFG1, md)
        other:
            return ((c >> core.ADDRFILT) & core.ADDRFILT_BITS)


PUB afc_auto_ena(s=-2): c
' Enable automatic AFC
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.RXCFG)
    case abs(s)
        0, 1:
            s := abs(s) << core.AFCAUTOON
            s := ((c & core.AFCAUTOON_MASK) | s)
            writereg(core.RXCFG, s)
        other:
            return (((c >> core.AFCAUTOON) & 1) == 1)


PUB afc_offset(): o
' Read AFC frequency offset
'   Returns: Frequency offset in Hz
    o := readreg(core.AFCMSB, 2)
    return (~~o) * FSTEP


PUB agc_mode(md=-2): c
' Enable AGC
'   Valid values:
'       TRUE(-1 or 1): LNA gain is controlled by the AGC
'       *FALSE (0): LNA gain is forced by the lna_gain() setting
'   Any other value polls the chip and returns the current setting
    c := readreg(core.RXCFG)
    case abs(md)
        0, 1:
            md := abs(md) << core.AGCAUTOON
            md := ((c & core.AGCAUTOON_MASK) | md)
            writereg(core.RXCFG, md)
        other:
            return (((c >> core.AGCAUTOON) & 1) == 1)


PUB bcast_addr(a=-2): c
' Set broadcast address
'   Valid values: $00..$FF
'   Any other value polls the chip and returns the current setting
    case a
        $00..$FF:
            writereg(core.BCASTADDR, a)
        other:
            return readreg(core.BCASTADDR)


PUB carrier_freq(frq=-2): c | opmode_orig
' Set carrier frequency, in Hz
'   Valid values: See case table below
'   Any other value polls the chip and returns the current setting
'   NOTE: The default is 434_000_000
    opmode_orig := 0
    case frq
        137_000_000..175_000_000, 410_000_000..525_000_000, 862_000_000..1_020_000_000:
            frq := u64.multdiv(frq, FPSCALE, FSTEP)
            opmode_orig := opmode()
            opmode(STDBY)
            writereg(core.FRFMSB, frq, 3)
            opmode(opmode_orig)
        other:
            c := readreg(core.FRFMSB, 3)
            return u64.multdiv(FSTEP, c, FPSCALE)


PUB clk_out(d=-2): c
' Set clkout frequency, as a divisor of FXOSC
'   Valid values:
'       1, 2, 4, 8, 16, 32, CLKOUT_RC (6), CLKOUT_OFF (7)
'   Any other value polls the chip and returns the current setting
'   NOTE: For optimal efficiency, it is recommended to disable the clock output (CLKOUT_OFF)
'       unless needed
    c := readreg(core.OSC)
    case d
        1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF:
            d := lookdownz(d: 1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF)
            d := ((c & core.CLKOUT_MASK) | d) & core.OSC_MASK
            writereg(core.OSC, d)
        other:
            c &= core.CLKOUT_BITS
            return lookupz(c: 1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF)


PUB crc_check_ena(e=-2): c
' Enable CRC calculation (TX) and checking (RX)
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.PKTCFG1)
    case abs(e)
        0, 1:
            e := abs(e) << core.CRCON
            e := ((c & core.CRCON_MASK) | e)
            writereg(core.PKTCFG1, e)
        other:
            return (((c >> core.CRCON) & 1) == 1)


PUB data_mode(md=-2): c
' Set data processing mode
'   Valid values:
'       DATAMODE_CONT (0): Continuous mode
'      *DATAMODE_PKT (1): Packet mode
'   Any other value polls the chip and returns the current setting
    c := readreg(core.PKTCFG2)
    case md
        DATAMODE_CONT, DATAMODE_PKT:
            md := md << core.DATAMODE
            md := ((c & core.DATAMODE_MASK) | md)
            writereg(core.PKTCFG2, md)
        other:
            return ((c >> core.DATAMODE) & 1)


PUB data_rate(r=-2): c
' Set on-air data rate, in bits per second
'   Valid values:
'       1_200..300_000
'   Any other value polls the chip and returns the current setting
'   NOTE: Result will be rounded
'   NOTE: Effective data rate will be halved if Manchester encoding is used
    case r
        1_200..300_000:
            r := (FXOSC / r)
            writereg(core.BITRATEMSB, r, 2)
        other:
            c := readreg(core.BITRATEMSB, 2)
            return (FXOSC / c)


PUB data_whiten_ena(e=-2): c
' Enable data whitening
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting and manchest_enc_ena() are mutually exclusive;
'       enabling this will disable manchest_enc_ena()
    c := readreg(core.PKTCFG1)
    case abs(e)
        0:
        1:
            e := DCFREE_WHITE << core.DCFREE
        other:
            c := ((c >> core.DCFREE) & core.DCFREE_BITS)
            return (c == DCFREE_WHITE)

    e := ((c & core.DCFREE_MASK) | e)
    writereg(core.PKTCFG1, e)


PUB dev_id(): id
' Version code of the chip
'   Returns:
'       Bits 7..4: full revision number
'       Bits 3..0: metal mask revision number
'   Known values: $11, $12
    return readreg(core.VERSION)


PUB fifo_empty(): e
' Flag indicating FIFO empty
'   Returns:
'       TRUE (-1): FIFO empty
'       FALSE (0): FIFO contains at least one byte
    return ( (interrupt() & INT_FIFOEMPTY) == INT_FIFOEMPTY )


PUB fifo_full(): f
' Flag indicating FIFO full
'   Returns:
'       TRUE (-1): FIFO full
'       FALSE (0): at least one byte available
    return ( (interrupt() & INT_FIFOFULL) == INT_FIFOFULL )


PUB fifo_int_thresh(thr=-2): c
' Set threshold for triggering FIFO level interrupt
'   Valid values: 1..64
'   Any other value polls the chip and returns the current setting
    c := readreg(core.FIFOTHRESH)
    case thr
        1..64:
            thr -= 1
            thr := ((c & core.FIFOTHR_MASK) | thr)
            writereg(core.FIFOTHRESH, thr)
        other:
            return ((c & core.FIFOTHR_BITS) + 1)


PUB freq_dev(d=-2): c
' Set carrier deviation, in Hz
'   Valid values:
'       600..300_000
'       Default is 5_000
'   Any other value polls the chip and returns the current setting
'   NOTE: Set value will be rounded
    case d
        600..300_000:
            ' freq deviation reg = (freq deviation / FSTEP)
            d := u64.multdiv(d, FPSCALE, FSTEP)
            writereg(core.FDEVMSB, d, 2)
        other:
            c := readreg(core.FDEVMSB, 2)
            return u64.multdiv(c, FSTEP, FPSCALE)


PUB freq_error(): e | bw
' Estimated frequency error from modem
    e := readreg(core.FEIMSB, 3)
    bw := rx_bw()
    e := u64.multdiv(e, TWO_24, FXOSC)
    return (e * (bw / 500))


PUB gaussian_filt(md=-2): c
' Set Gaussian filter/data shaping parameters
'   Valid values:
'      *BT_NONE (0): No shaping
'       BT_1_0 (1): Gaussian filter, BT = 1.0
'       BT_0_5 (2): Gaussian filter, BT = 0.5
'       BT_0_3 (3): Gaussian filter, BT = 0.3
'   Any other value polls the chip and returns the current setting
    c := readreg(core.PARAMP)
    case md
        BT_NONE..BT_0_3:
            md := md << core.MODSHP
            md := ((c & core.MODSHP_MASK) | md)
            writereg(core.PARAMP, md)
        other:
            return ((c >> core.MODSHP) & core.MODSHP_BITS)


PUB gpio0(md=-2): c
' Assert DIO0 pin on set mode
'   Valid values:
'       DIO0_RXDONE (0) - Packet reception complete
'       DIO0_TXDONE (64) - FIFO payload transmission complete
'       DIO0_CADDONE (128) - Channel Activity Detected
    c := readreg(core.DIOMAP1)
    case md
        DIO0_RXDONE, DIO0_TXDONE, DIO0_CADDONE:
            md <<= core.DIO0MAP
            md := ((c & core.DIO0MAP_MASK) | md) & core.DIOMAP1_MASK
            writereg(core.DIOMAP1, md)
        other:
            return (c >> core.DIO0MAP) & %11


PUB gpio1(md=-2): c
' Assert DIO1 pin on set mode
'   Valid values:
'       DIO1_RXTIMEOUT (0) - Packet reception timed out
'       DIO1_FHSSCHANGECHANNEL (64) - FHSS Changed channel
'       DIO1_CADDETECTED (128) - Channel Activity Detected
    c := readreg(core.DIOMAP1)
    case md
        DIO1_RXTIMEOUT, DIO1_FHSSCHANGECHANNEL, DIO1_CADDETECTED:
            md <<= core.DIO1MAP
            md := ((c & core.DIO1MAP_MASK) | md) & core.DIOMAP1_MASK
            writereg(core.DIOMAP1, md)
        other:
            return (c >> core.DIO1MAP) & %11


PUB gpio2(md=-2): c
' Assert DIO2 pin on set mode
'   Valid values:
'       DIO2_FHSSCHANGECHANNEL (0) - FHSS Changed channel
'       DIO2_FHSSCHANGECHANNEL (64) - FHSS Changed channel
'       DIO2_FHSSCHANGECHANNEL (128) - FHSS Changed channel
    c := readreg(core.DIOMAP1)
    case md
        DIO2_FHSSCHANGECHANNEL, DIO2_SYNCADDRESS:
            md <<= core.DIO2MAP
            md := ((c & core.DIO2MAP_MASK) | md) & core.DIOMAP1_MASK
            writereg(core.DIOMAP1, md)
        other:
            return (c >> core.DIO2MAP) & %11


PUB gpio3(md=-2): c
' Assert DIO3 pin on set mode
'   Valid values:
'       DIO3_CADDONE (0) - Channel Activity Detection complete
'       DIO3_VALIDHDR (64) - Valider header received in RX mode
'       DIO3_PAYLDCRCERROR (128) - CRC error in received payload
    c := readreg(core.DIOMAP1)
    case md
        DIO3_CADDONE, DIO3_VALIDHDR, DIO3_PAYLDCRCERROR:
            md <<= core.DIO3MAP
            md := ((c & core.DIO3MAP_MASK) | md) & core.DIOMAP1_MASK
            writereg(core.DIOMAP1, md)
        other:
            return c & %11


PUB gpio4(md=-2): c
' Assert DIO4 pin on set mode
'   Valid values:
'       DIO4_CADDETECTED (0) - Channel Activity Detected
'       DIO4_PLLLOCK (64) - PLL Locked
'       DIO4_PLLLOCK (128) - PLL Locked
    c := readreg(core.DIOMAP2)
    case md
        DIO4_CADDETECTED, DIO4_PLLLOCK:
            md <<= core.DIO4MAP
            md := ((c & core.DIO4MAP_MASK) | md) & core.DIOMAP2_MASK
            writereg(core.DIOMAP2, md)
        other:
            return (c >> core.DIO4MAP) & %11


PUB gpio5(md=-2): c
' Assert DIO5 pin on set mode
'   Valid values:
'       DIO5_MODEREADY (0) - Requested operation mode is ready
'       DIO5_CLKOUT (64) - Output system clock
'       DIO5_CLKOUT (128) - Output system clock
    c := readreg(core.DIOMAP2)
    case md
        DIO5_MODEREADY, DIO5_CLKOUT:
            md <<= core.DIO5MAP
            md := ((c & core.DIO5MAP_MASK) | md) & core.DIOMAP2_MASK
            writereg(core.DIOMAP2, md)
        other:
            return (c >> core.DIO5MAP) & %11


PUB idle()
' Change chip state to idle (standby)
    opmode(STDBY)


PUB int_clear(m)
' Clear interrupt flags
'   Valid values:
'   Bits 15..0
'       11: RSSI exceeds rssi_int_thresh()
'       9: Valid preamble detected
'       8: Matching syncword (and address, if enabled) detected
'       4: FIFO has overrun
'       0: Battery voltage < low batt threshold
'   Any other value is ignored
    if ( m & core.WR_CLR_BITS )
            ' interrupt bits set (1) in the mask were chosen to be cleared
            ' to actually clear them, invert all of the bits
            ' so the 1's become 0's (other bits are ignored)
            m ^= core.IRQFLAGS_MASK
            writereg(core.IRQFLAGS1, m, 2)
    else
        return


PUB interrupt(): i
' Read interrupt flags
'   Returns: Interrupt flags as a mask
'   Bits 15..0
'       15: OpMode ready (clears when changing opmode())
'       14: Receive ready (clears when leaving RX mode)
'       13: Transmit ready (clears when leaving TX mode)
'       12: PLL locked (TX or RX)
'       11: RSSI exceeds rssi_int_thresh()
'       10: Timeout (clears when leaving RX mode or FIFO emptied)
'       9: Valid preamble detected
'       8: Matching syncword (and address, if enabled) detected
'       7: FIFO is full (66 bytes)
'       6: FIFO is empty
'       5: FIFO level exceeds threshold
'       4: FIFO has overrun
'       3: Packet sent (clears when leaving TX opmode)
'       2: Payload ready (and CRC is OK, if enabled)
'       1: CRC OK (cleared when FIFO empty)
'       0: Battery voltage < low batt threshold
    return readreg(core.IRQFLAGS1, 2)


PUB int_mask(m=-2): c
' Set interrupt mask
'   Valid values:
'   Bits 15..0
'       11: RSSI exceeds rssi_int_thresh()
'       9: Valid preamble detected
'       8: Matching syncword (and address, if enabled) detected
'       4: FIFO has overrun
'       0: Battery voltage < low batt threshold
'   Any other value is ignored
    if ( m & core.WR_CLR_BITS )
        writereg(core.IRQFLAGS1, m, 2)
    else
        return


PUB lna_gain(g=-255): c
' Set LNA gain, in dB
'   Valid values: *0 (Maximum gain), -6, -12, -24, -36, -48
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting will have no effect if AGC is enabled
'   NOTE: The current setting returned may be different than what was
'       explicitly set, if the AGC is enabled
    c := readreg(core.LNA)
    case g
        0, -6, -12, -24, -36, -48:
            g := lookdown(g: 0, -6, -12, -24, -36, -48) << core.LNAGAIN
            g := ((c & core.LNAGAIN_MASK) | g) & core.LNA_MASK
            writereg(core.LNA, c)
        other:
            c := (c >> core.LNAGAIN) & core.LNAGAIN_BITS
            return lookup(c: 0, -6, -12, -24, -36, -48)


PUB low_batt_lvl(lvl=-2): c
' Set low battery threshold, in millivolts
'   Valid values:
'       1695, 1764, *1835, 1905, 1976, 2045, 2116, 2185
'   Any other value polls the chip and returns the current setting
    c := readreg(core.LOWBAT)
    case lvl
        1695, 1764, 1835, 1905, 1976, 2045, 2116, 2185:
            lvl := lookdownz(lvl: 1695, 1764, 1835, 1905, 1976, 2045, 2116, 2185)
            lvl := ((c & core.LOWBATTRIM_MASK) | lvl)
            writereg(core.LOWBAT, lvl)
        other:
            c &= core.LOWBATTRIM_BITS
            return lookupz(c: 1695, 1764, 1835, 1905, 1976, 2045, 2116, 2185)


PUB low_batt_mon_ena(e=-2): c
' Enable low battery detector signal
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.LOWBAT)
    case abs(e)
        0, 1:
            e := abs(e) << core.LOWBATON
            e := ((c & core.LOWBAT_MASK) | e)
            writereg(core.LOWBAT, e)
        other:
            return (((c >> core.LOWBATON) & 1) == 1)


PUB low_freq_mode(md=-2): c
' Enable Low frequency-specific register access
'   Valid values:
'       TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.OPMODE)
    case abs(md)
        0, 1:
            md := (abs(md) << core.LOWFREQMODEON)
            md := ((c & core.LOWFREQMODEON_MASK) | md)
            writereg(core.OPMODE, md)
        other:
            return ((c >> core.LOWFREQMODEON) & 1) == 1


PUB manchest_enc_ena(s=-2): c
' Enable Manchester encoding/decoding
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting and data_whiten_ena() are mutually exclusive;
'       enabling this will disable data_whiten_ena()
    c := readreg(core.PKTCFG1)
    case abs(s)
        0:                                      ' disabled s is just 0, so
        1:                                      '   just leave it as-is
            s := DCFREE_MANCH << core.DCFREE
        other:
            c := ((c >> core.DCFREE) & core.DCFREE_BITS)
            return (c == DCFREE_MANCH)

    s := ((c & core.DCFREE_MASK) | s)
    writereg(core.PKTCFG1, s)


PUB modulation(md=-2): c | lr_mode, opmode_orig
' Set modulation type
'   Valid values:
'      *FSK (0): FSK packet radio mode
'       OOK (1): OOK packet radio mode
'   Any other value polls the chip and returns the current setting
    c := readreg(core.OPMODE)
    opmode_orig := (c & core.MODE_BITS)         ' cache user's current opmode
    case md
        FSK, OOK:
            md <<= core.MODTYPE
            ' set operating md to SLEEP (required to change the LORAMODE bit)
            md := (c & core.MODE_MASK & core.MODTYPE_MASK) | md
            writereg(core.OPMODE, md)

            time.usleep(core.T_POR)             ' wait for chip to be ready
            opmode(opmode_orig)                 ' restore user's opmd
        other:
            return ((c >> core.MODTYPE) & core.MODTYPE_BITS)


PUB node_addr(a=-2): c
' Set node address
'   Valid values: $00..$FF
'   Any other value polls the chip and returns the current setting
    case a
        $00..$FF:
            writereg(core.NODEADDR, a)
        other:
            return readreg(core.NODEADDR)


PUB ocp_current(lvl=-2): c
' Trim over-current protection, to milliamps
'   Valid values: 45..240mA
'   Any other value polls the chip and returns the lvl setting
    c := readreg(core.OCP)
    case lvl
        45..120:
            lvl := (lvl - 45) / 5
        130..240:
            lvl := (lvl - -30) / 10
        other:
            c := c & core.OCPTRIM
            case c
                0..15:
                    return 45 + 5 * c
                16..27:
                    return -30 + 10 * c
                28..31:
                    return 240
            return

    lvl := ((c & core.OCPTRIM_MASK) | lvl)
    writereg(core.OCP, lvl)


PUB oc_protect_ena(e=-2): c
' Enable over-current protection for PA
'   Valid values:
'      *TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.OCP)
    case abs(e)
        0, 1:
            e := abs(e) << core.OCPON
            e := ((c & core.OCPON_MASK) | e) & core.OCP_MASK
            writereg(core.OCP, e)
        other:
            return (((c >> core.OCPON) & 1) == 1)


PUB opmode(md=-2): c | modemask
' Set device operating mode
'   Valid values:
'       SLEEPMODE (%000): Sleep
'      *STDBY (%001): Standby
'       FSTX (%010): Frequency synthesis TX
'       TX (%011): Transmit
'       FSRX (%100): Frequency synthesis RX
'       RXCONT (%101): Receive continuous
'   Any other value polls the chip and returns the current setting
    c := readreg(core.OPMODE)
    case md
        SLEEPMODE..RXCONT:
            md := ((c & core.MODE_MASK) | md)
            writereg(core.OPMODE, md)
        other:
            return c & core.MODE_BITS


PUB pa_ramp_time(t=-2): c
' Set Rise/fall time of FSK ramp up/down, in microseconds
'   Valid values: 3400, 2000, 1000, 500, 250, 125, 100, 62, 50, *40, 31, 25, 20, 15, 12, 10
'   Any other value polls the chip and returns the current setting
    c := readreg(core.PARAMP)
    case t
        3400, 2000, 1000, 500, 250, 125, 100, 62, 50, 40, 31, 25, 20, 15, 12, 10:
            t := lookdownz(t: 3400, 2000, 1000, 500, 250, 125, 100, 62, 50, 40, ...
                                            31, 25, 20, 15, 12, 10)
            t := ((c & core.PA_RAMP_MASK) | t)
            writereg(core.PARAMP, t)
        other:
            c &= core.PA_RAMP_BITS
            return lookupz(c:   3400, 2000, 1000, 500, 250, 125, 100, 62, 50, 40, 31, ...
                                        25, 20, 15, 12, 10)


PUB payld_len(len=-2): c
' Set payload length, in bytes
'   Valid values: 1..64 (FSK/OOK)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.PKTCFG2, 2)
    if ( lookdown(len: 1..64) )
        len := ((c & core.PAYLDLEN_MASK) | len)
        writereg(core.PKTCFG2, len, 2)
    else
        return (c & core.PAYLDLEN_BITS)


PUB payld_len_cfg(md=-2): c
' Set payload length configuration/mode
'   Valid values:
'       PKTLEN_FIXED (0): Fixed-length payload
'      *PKTLEN_VAR (1): Variable-length payload
'   Any other value polls the chip and returns the current setting
    c := readreg(core.PKTCFG1)
    case md
        0, 1:
            md <<= core.PKTFORMAT
            md := ((c & core.PKTFORMAT_MASK) | md)
            writereg(core.PKTCFG1, md)
        other:
            return ((c >> core.PKTFORMAT) & 1)


PUB payld_rdy(): r
' Flag indicating payload received/ready
'   Returns:
'       TRUE (-1): payload ready
'       FALSE (0): no payload received
'   NOTE: Once set, this flag clears when FIFO is emptied
    return ((interrupt() & INT_PAYLDREADY) == INT_PAYLDREADY)


PUB payld_sent(): s
' Flag indicating payload sent
'   Returns:
'       TRUE (-1): payload sent
'       FALSE (0): payload not sent
'   NOTE: Once set, this flag clears when exiting TX mode
    return ((interrupt() & INT_PACKETSENT) == INT_PACKETSENT)


PUB pll_locked(): l
' Return PLL lock status, while attempting a TX, RX, or CAD operation
'   Returns:
'       0: PLL didn't lock
'       1: PLL locked


PUB preamble_len(len=-2):  c
' Set preamble length, in bytes
'   Valid values: 0..65535 (default: 3)
'   Any other value polls the chip and returns the current setting
    case len
        0..65535:
            writereg(core.PREAMBLEMSB, len, 2)
        other:
            return readreg(core.PREAMBLEMSB, 2)


PUB rc_osc_cal(e=-2): c
' Trigger calibration of RC oscillator
'   Valid values:
'       TRUE (-1 or 1)
'   Any other value is ignored
    c := readreg(core.OSC)
    case abs(e)
        1:
            e := abs(e) << core.RCCALSTART
            e := (c & core.RCCALSTART_MASK | e)
            writereg(core.OSC, e)
        other:
            return


PUB reset()
' Perform soft-reset
    if lookdown(_RESET: 0..31)                  ' if a valid pin is set,
        outa[_RESET] := 0                       ' pull NRESET low for 100uS,
        dira[_RESET] := 1
        time.usleep(core.T_RESACTIVE)
        dira[_RESET] := 0                       '   then let it float
        time.usleep(core.T_RES)                 ' wait for the chip to be ready


PUB rssi(): v
' Current RSSI, in dBm
    v := readreg(core.RSSIVALUE)
    return -(v / 2)


PUB rssi_int_thresh(thr=-255): c
' Set threshold for triggering RSSI interrupt, in dBm
'   Valid values: -127..0
'   Any other value polls the chip and returns the current setting
    case thr
        -127..0:
            thr := abs(thr) * 2
            writereg(core.RSSITHRESH, thr)
        other:
            c := readreg(core.RSSITHRESH)
            return -(c / 2)


PUB rx_bw(bw=-2): c | exp_mod, exp, mant, mant_tmp, rxb_calc
' Set receive bandwidth, in Hz (* single side-band)
'   Valid values:
'       2604, 3125, 3906, 5208, 6250, 7812, 10416, 12500, 15625,
'       20833, 25000, 31250, 41666, 50000, 62500, 83333, 100000, 125000,
'       166666, 200000, 250000, 333333, 400000, 500000
'   Any other value polls the chip and returns the current setting
'   NOTE: In the 169MHz band, 250_000 and 500_000 are not supported
    c := readreg(core.RXBW)
    ' exponent differs depending on FSK or OOK modulation
    exp_mod := lookupz(modulation(): 2, 3)
    case bw
        2_604..500_000:
            ' iterate through combinations of exponent and mantissa settings
            '   until a (close) match to the requested BW is found
            repeat exp from 7 to 0
                repeat mant from 2 to 0
                    mant_tmp := lookupz(mant: 16, 20, 24)
                    rxb_calc := FXOSC / (mant_tmp * (1 << (exp + exp_mod)))
                    if (rxb_calc => bw)
                        quit
                if (rxb_calc => bw)
                    quit
            bw := (mant << 3) | exp
            bw := ((c & core.RX_BW_MASK) | bw)
            writereg(core.RXBW, bw)
        other:
            exp := (c & core.RXBWEXP_BITS)
            mant := ((c >> core.RXBWMANT) & core.RXBWMANT_BITS)
            mant := lookupz(mant: 16, 20, 24)
            return (FXOSC / (mant * (1 << (exp + exp_mod))))


PUB rx_mode()
' Change chip state to RX (receive)
    opmode(RXCONT)


PUB rx_payld(len, p_dest)
' Receive data from RX FIFO into buffer at ptr_buff
'   Valid values: nr_bytes - 1..64
'   Any other value is ignored
    case len
        1..64:
            readreg(core.FIFO, len, p_dest)
        other:
            return


PUB sleep()
' Power down chip
    opmode(SLEEPMODE)


PUB set_syncwd(p_src)
' Set sync word
'   ptr_syncwd: pointer to copy syncword data from
'   NOTE: 8 bytes will be read from ptr_syncwd
    writereg(core.SYNCVALUE1, p_src, 8)


PUB syncwd(p_dest): p
' Get current sync word
'   ptr_syncwd: pointer to copy syncword data to
'   NOTE: Variable pointed to by ptr_buff must be at least 8 bytes in length
    readreg(core.SYNCVALUE1, 8, p_dest)


PUB syncwd_ena(e=-2): c
' Enable sync word generation (TX) and detection (RX)
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.SYNCCFG)
    case abs(e)
        0, 1:
            e := abs(e) << core.SYNCON
            e := ((c & core.SYNCON_MASK) | e)
            writereg(core.SYNCCFG, e)
        other:
            return (((c >> core.SYNCON) & 1) == 1)


PUB syncwd_len(len=-2): g
' Set length of sync word, in bytes
'   Valid values: 1..8
'   Any other value polls the chip and returns the current setting
    g := readreg(core.SYNCCFG)
    case len
        1..8:
            len := (len-1) << core.SYNCSZ
            len := ((g & core.SYNCSZ_MASK) | len)
            writereg(core.SYNCCFG, len)
        other:
            return (((g >> core.SYNCSZ) & core.SYNCSZ_BITS) + 1)


PUB tx_mode()
' Change chip state to transmit
    opmode(TX)


PUB tx_payld(len, p_src)
' Queue data to be transmitted in the TX FIFO
'   nr_bytes Valid values: 1..64
'   Any other value is ignored
    case len
        1..64:
            writereg(core.FIFO, len, p_src)
        other:
            return


PUB tx_pwr(pwr=-255): c | pa_dac
' Set transmit power, in dBm
'   Valid values:
'       -1..14 (when tx_sig_routing() == RFO)
'       5..23 (when tx_sig_routing() == PABOOST)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.PACFG)
    pa_dac := readreg(core.PADAC)
    case _txsig_routing
        RFO:
            case pwr
                -1..14:
                    c := (7 << core.MAXPWR) | (pwr + 1)
                other:
                    return (c & core.OUTPUTPWR_BITS) - 1
            writereg(core.PACFG, c)
        PABOOST:
            case pwr
                5..20:
                    pa_dac := core.PADAC_RSVD_DEF | core.PA_DEF ' preserve the
                21..23:                                         ' reserved bits
                    pa_dac := core.PADAC_RSVD_DEF | core.PA_BOOST
                    pwr -= 3
                other:
                    case pa_dac & core.PA_DAC_BITS
                        core.PA_DEF:
                            return (c & core.OUTPUTPWR_BITS) + 5
                        core.PA_BOOST:
                            return (c & core.OUTPUTPWR_BITS) + 8
                        other:
                            return pa_dac
                    return
            c := (1 << core.PASELECT) | (pwr - 5)
            writereg(core.PADAC, pa_dac)
            writereg(core.PACFG, c)
        other:
            return (c & core.OUTPUTPWR_BITS) - 1


PUB tx_sig_routing(r=-2): c
' Set transmit signal output routing
'   Valid values:
'      *RFO (0): Signal routed to RFO pin, max power is +14dBm
'       PABOOST (128): Signal routed to PA_BOOST pin, max power is +23dBm
'   NOTE: This has a direct effect on the maximum output power available
'       using the tx_pwr() method
    case r
        RFO, PABOOST:
            _txsig_routing := r
        other:
            return _txsig_routing


PUB tx_start_cond(cnd=-2): c
' Define condition required to begin packet transmission
'   Valid values:
'       TXSTART_FIFOLVL (0): If the number of bytes in the FIFO exceeds
'           fifo_int_thresh()
'      *TXSTART_FIFONOTEMPTY (1): If there's at least one byte in the FIFO
'   Any other value polls the chip and returns the current setting
    c := readreg(core.FIFOTHRESH)
    case cnd
        TXSTART_FIFOLVL, TXSTART_FIFONOTEMPTY:
            cnd <<= core.TXSTARTCOND
            cnd := ((c & core.TXSTARTCOND_MASK) | cnd)
            writereg(core.FIFOTHRESH, cnd)
        other:
            return ((c >> core.TXSTARTCOND) & 1)


PRI readreg(reg_nr, len=1, p_dest=0): v | tmp
' Read nr_bytes from device into ptr_buff
    if ( len =< 4 )
        p_dest := @v

    outa[_CS] := 0
        spi.wr_byte(reg_nr)
        spi.rdblock_msbf(p_dest, len)           ' read MS-byte first
    outa[_CS] := 1


PRI writereg(reg_nr, val, len=1) | tmp, p_src
' Write nr_bytes from ptr_buff to device
    if ( (len > 4) )
        p_src := val
    else
        p_src := @val
    outa[_CS] := 0
        spi.wr_byte(reg_nr | core.SPI_WR)       ' must set WNR bit to write
        spi.wrblock_msbf(p_src, len)            ' write MS-byte first
    outa[_CS] := 1


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

