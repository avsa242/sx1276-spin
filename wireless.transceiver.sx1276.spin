{
----------------------------------------------------------------------------------------------------
    Filename:       wireless.transceiver.sx1276.spin
    Description:    Driver for the SEMTECH SX1276 FSK/OOK transceiver
    Author:         Jesse Burt
    Started:        Oct 6, 2019
    Updated:        Oct 14, 2024
    Copyright (c) 2024 - See end of file for terms of use.
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


PUB addr_check(mode=-2): curr_mode
' Enable address checking/matching/filtering
'   Valid values:
'       ADDRCHK_NONE (%00): No address check
'       ADDRCHK_CHK_NO_BCAST (%01): Check address, but ignore broadcast addresses
'       ADDRCHK_CHK_00_BCAST (%10): Check address, and also respond to broadcast address
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core.PKTCFG1, 1, @curr_mode)
    case mode
        ADDRCHK_NONE, ADDRCHK_CHK_NO_BCAST, ADDRCHK_CHK_BCAST:
            mode <<= core.ADDRFILT
            mode := ((curr_mode & core.ADDRFILT_MASK) | mode)
            writereg(core.PKTCFG1, 1, @mode)
        other:
            return ((curr_mode >> core.ADDRFILT) & core.ADDRFILT_BITS)


PUB afc_auto_ena(state=-2): curr_state
' Enable automatic AFC
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core.RXCFG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core.AFCAUTOON
            state := ((curr_state & core.AFCAUTOON_MASK) | state)
            writereg(core.RXCFG, 1, @state)
        other:
            return (((curr_state >> core.AFCAUTOON) & 1) == 1)


PUB afc_offset(): offs
' Read AFC frequency offset
'   Returns: Frequency offset in Hz
    offs := 0
    readreg(core.AFCMSB, 2, @offs)
    return (~~offs) * FSTEP


PUB agc_mode(state=-2): curr_state
' Enable AGC
'   Valid values:
'       TRUE(-1 or 1): LNA gain is controlled by the AGC
'       *FALSE (0): LNA gain is forced by the lna_gain() setting
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core.RXCFG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core.AGCAUTOON
            state := ((curr_state & core.AGCAUTOON_MASK) | state)
            writereg(core.RXCFG, 1, @state)
        other:
            return (((curr_state >> core.AGCAUTOON) & 1) == 1)


PUB bcast_addr(addr=-2): curr_addr
' Set broadcast address
'   Valid values: $00..$FF
'   Any other value polls the chip and returns the current setting
    case addr
        $00..$FF:
            writereg(core.BCASTADDR, 1, @addr)
        other:
            curr_addr := 0
            readreg(core.BCASTADDR, 1, @curr_addr)
            return


PUB carrier_freq(freq=-2): curr_freq | opmode_orig
' Set carrier frequency, in Hz
'   Valid values: See case table below
'   Any other value polls the chip and returns the current setting
'   NOTE: The default is 434_000_000
    opmode_orig := 0
    case freq
        137_000_000..175_000_000, 410_000_000..525_000_000, 862_000_000..1_020_000_000:
            freq := u64.multdiv(freq, FPSCALE, FSTEP)
            opmode_orig := opmode()
            opmode(STDBY)
            writereg(core.FRFMSB, 3, @freq)
            opmode(opmode_orig)
        other:
            curr_freq := 0
            readreg(core.FRFMSB, 3, @curr_freq)
            return u64.multdiv(FSTEP, curr_freq, FPSCALE)


PUB clk_out(divisor=-2): curr_div
' Set clkout frequency, as a divisor of FXOSC
'   Valid values:
'       1, 2, 4, 8, 16, 32, CLKOUT_RC (6), CLKOUT_OFF (7)
'   Any other value polls the chip and returns the current setting
'   NOTE: For optimal efficiency, it is recommended to disable the clock output (CLKOUT_OFF)
'       unless needed
    curr_div := 0
    readreg(core.OSC, 1, @curr_div)
    case divisor
        1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF:
            divisor := lookdownz(divisor: 1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF)
            divisor := ((curr_div & core.CLKOUT_MASK) | divisor) & core.OSC_MASK
            writereg(core.OSC, 1, @divisor)
        other:
            curr_div &= core.CLKOUT_BITS
            return lookupz(curr_div: 1, 2, 4, 8, 16, 32, CLKOUT_RC, CLKOUT_OFF)


PUB crc_check_ena(state=-2): curr_state
' Enable CRC calculation (TX) and checking (RX)
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core.PKTCFG1, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core.CRCON
            state := ((curr_state & core.CRCON_MASK) | state)
            writereg(core.PKTCFG1, 1, @state)
        other:
            return (((curr_state >> core.CRCON) & 1) == 1)


PUB data_mode(mode=-2): curr_mode
' Set data processing mode
'   Valid values:
'       DATAMODE_CONT (0): Continuous mode
'      *DATAMODE_PKT (1): Packet mode
'   Any other value polls the chip and returns the current setting
    readreg(core.PKTCFG2, 1, @curr_mode)
    case mode
        DATAMODE_CONT, DATAMODE_PKT:
            mode := mode << core.DATAMODE
            mode := ((curr_mode & core.DATAMODE_MASK) | mode)
            writereg(core.PKTCFG2, 1, @mode)
        other:
            return ((curr_mode >> core.DATAMODE) & 1)


PUB data_rate(rate=-2): curr_rate
' Set on-air data rate, in bits per second
'   Valid values:
'       1_200..300_000
'   Any other value polls the chip and returns the current setting
'   NOTE: Result will be rounded
'   NOTE: Effective data rate will be halved if Manchester encoding is used
    case rate
        1_200..300_000:
            rate := (FXOSC / rate)
            writereg(core.BITRATEMSB, 2, @rate)
        other:
            curr_rate := 0
            readreg(core.BITRATEMSB, 2, @curr_rate)
            return (FXOSC / curr_rate)


PUB data_whiten_ena(state=-2): curr_state
' Enable data whitening
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting and manchest_enc_ena() are mutually exclusive;
'       enabling this will disable manchest_enc_ena()
    curr_state := 0
    readreg(core.PKTCFG1, 1, @curr_state)
    case ||(state)
        0:
        1:
            state := DCFREE_WHITE << core.DCFREE
        other:
            curr_state := ((curr_state >> core.DCFREE) & core.DCFREE_BITS)
            return (curr_state == DCFREE_WHITE)

    state := ((curr_state & core.DCFREE_MASK) | state)
    writereg(core.PKTCFG1, 1, @state)


PUB dev_id(): id
' Version code of the chip
'   Returns:
'       Bits 7..4: full revision number
'       Bits 3..0: metal mask revision number
'   Known values: $11, $12
    id := 0
    readreg(core.VERSION, 1, @id)


PUB fifo_empty(): flag
' Flag indicating FIFO empty
'   Returns:
'       TRUE (-1): FIFO empty
'       FALSE (0): FIFO contains at least one byte
    return ( (interrupt() & INT_FIFOEMPTY) == INT_FIFOEMPTY )


PUB fifo_full(): flag
' Flag indicating FIFO full
'   Returns:
'       TRUE (-1): FIFO full
'       FALSE (0): at least one byte available
    return ( (interrupt() & INT_FIFOFULL) == INT_FIFOFULL )


PUB fifo_int_thresh(thresh=-2): curr_thr
' Set threshold for triggering FIFO level interrupt
'   Valid values: 1..64
'   Any other value polls the chip and returns the current setting
    curr_thr := 0
    readreg(core.FIFOTHRESH, 1, @curr_thr)
    case thresh
        1..64:
            thresh -= 1
            thresh := ((curr_thr & core.FIFOTHR_MASK) | thresh)
            writereg(core.FIFOTHRESH, 1, @thresh)
        other:
            return ((curr_thr & core.FIFOTHR_BITS) + 1)


PUB freq_dev(fdev=-2): curr_fdev
' Set carrier deviation, in Hz
'   Valid values:
'       600..300_000
'       Default is 5_000
'   Any other value polls the chip and returns the current setting
'   NOTE: Set value will be rounded
    case fdev
        600..300_000:
            ' freq deviation reg = (freq deviation / FSTEP)
            fdev := u64.multdiv(fdev, FPSCALE, FSTEP)
            writereg(core.FDEVMSB, 2, @fdev)
        other:
            curr_fdev := 0
            readreg(core.FDEVMSB, 2, @curr_fdev)
            return u64.multdiv(curr_fdev, FSTEP, FPSCALE)


PUB freq_error(): ferr | bw
' Estimated frequency error from modem
    ferr := 0
    readreg(core.FEIMSB, 3, @ferr)
    bw := rx_bw()
    ferr := u64.multdiv(ferr, TWO_24, FXOSC)
    return (ferr * (bw / 500))


PUB gaussian_filt(mode=-2): curr_mode
' Set Gaussian filter/data shaping parameters
'   Valid values:
'      *BT_NONE (0): No shaping
'       BT_1_0 (1): Gaussian filter, BT = 1.0
'       BT_0_5 (2): Gaussian filter, BT = 0.5
'       BT_0_3 (3): Gaussian filter, BT = 0.3
'   Any other value polls the chip and returns the current setting
    readreg(core.PARAMP, 1, @curr_mode)
    case mode
        BT_NONE..BT_0_3:
            mode := mode << core.MODSHP
            mode := ((curr_mode & core.MODSHP_MASK) | mode)
            writereg(core.PARAMP, 1, @mode)
        other:
            return ((curr_mode >> core.MODSHP) & core.MODSHP_BITS)


PUB gpio0(mode=-2): curr_mode
' Assert DIO0 pin on set mode
'   Valid values:
'       DIO0_RXDONE (0) - Packet reception complete
'       DIO0_TXDONE (64) - FIFO payload transmission complete
'       DIO0_CADDONE (128) - Channel Activity Detected
    curr_mode := 0
    readreg(core.DIOMAP1, 1, @curr_mode)
    case mode
        DIO0_RXDONE, DIO0_TXDONE, DIO0_CADDONE:
            mode <<= core.DIO0MAP
            mode := ((curr_mode & core.DIO0MAP_MASK) | mode) & core.DIOMAP1_MASK
            writereg(core.DIOMAP1, 1, @mode)
        other:
            return (curr_mode >> core.DIO0MAP) & %11


PUB gpio1(mode=-2): curr_mode
' Assert DIO1 pin on set mode
'   Valid values:
'       DIO1_RXTIMEOUT (0) - Packet reception timed out
'       DIO1_FHSSCHANGECHANNEL (64) - FHSS Changed channel
'       DIO1_CADDETECTED (128) - Channel Activity Detected
    curr_mode := 0
    readreg(core.DIOMAP1, 1, @curr_mode)
    case mode
        DIO1_RXTIMEOUT, DIO1_FHSSCHANGECHANNEL, DIO1_CADDETECTED:
            mode <<= core.DIO1MAP
            mode := ((curr_mode & core.DIO1MAP_MASK) | mode) & core.DIOMAP1_MASK
            writereg(core.DIOMAP1, 1, @mode)
        other:
            return (curr_mode >> core.DIO1MAP) & %11


PUB gpio2(mode=-2): curr_mode
' Assert DIO2 pin on set mode
'   Valid values:
'       DIO2_FHSSCHANGECHANNEL (0) - FHSS Changed channel
'       DIO2_FHSSCHANGECHANNEL (64) - FHSS Changed channel
'       DIO2_FHSSCHANGECHANNEL (128) - FHSS Changed channel
    curr_mode := 0
    readreg(core.DIOMAP1, 1, @curr_mode)
    case mode
        DIO2_FHSSCHANGECHANNEL, DIO2_SYNCADDRESS:
            mode <<= core.DIO2MAP
            mode := ((curr_mode & core.DIO2MAP_MASK) | mode) & core.DIOMAP1_MASK
            writereg(core.DIOMAP1, 1, @mode)
        other:
            return (curr_mode >> core.DIO2MAP) & %11


PUB gpio3(mode=-2): curr_mode
' Assert DIO3 pin on set mode
'   Valid values:
'       DIO3_CADDONE (0) - Channel Activity Detection complete
'       DIO3_VALIDHDR (64) - Valider header received in RX mode
'       DIO3_PAYLDCRCERROR (128) - CRC error in received payload
    curr_mode := 0
    readreg(core.DIOMAP1, 1, @curr_mode)
    case mode
        DIO3_CADDONE, DIO3_VALIDHDR, DIO3_PAYLDCRCERROR:
            mode <<= core.DIO3MAP
            mode := ((curr_mode & core.DIO3MAP_MASK) | mode) & core.DIOMAP1_MASK
            writereg(core.DIOMAP1, 1, @mode)
        other:
            return curr_mode & %11


PUB gpio4(mode=-2): curr_mode
' Assert DIO4 pin on set mode
'   Valid values:
'       DIO4_CADDETECTED (0) - Channel Activity Detected
'       DIO4_PLLLOCK (64) - PLL Locked
'       DIO4_PLLLOCK (128) - PLL Locked
    curr_mode := 0
    readreg(core.DIOMAP2, 1, @curr_mode)
    case mode
        DIO4_CADDETECTED, DIO4_PLLLOCK:
            mode <<= core.DIO4MAP
            mode := ((curr_mode & core.DIO4MAP_MASK) | mode) & core.DIOMAP2_MASK
            writereg(core.DIOMAP2, 1, @mode)
        other:
            return (curr_mode >> core.DIO4MAP) & %11


PUB gpio5(mode=-2): curr_mode
' Assert DIO5 pin on set mode
'   Valid values:
'       DIO5_MODEREADY (0) - Requested operation mode is ready
'       DIO5_CLKOUT (64) - Output system clock
'       DIO5_CLKOUT (128) - Output system clock
    curr_mode := 0
    readreg(core.DIOMAP2, 1, @curr_mode)
    case mode
        DIO5_MODEREADY, DIO5_CLKOUT:
            mode <<= core.DIO5MAP
            mode := ((curr_mode & core.DIO5MAP_MASK) | mode) & core.DIOMAP2_MASK
            writereg(core.DIOMAP2, 1, @mode)
        other:
            return (curr_mode >> core.DIO5MAP) & %11


PUB idle()
' Change chip state to idle (standby)
    opmode(STDBY)


PUB int_clear(mask)
' Clear interrupt flags
'   Valid values:
'   Bits 15..0
'       11: RSSI exceeds rssi_int_thresh()
'       9: Valid preamble detected
'       8: Matching syncword (and address, if enabled) detected
'       4: FIFO has overrun
'       0: Battery voltage < low batt threshold
'   Any other value is ignored
    if ( mask & core.WR_CLR_BITS )
            ' interrupt bits set (1) in the mask were chosen to be cleared
            ' to actually clear them, invert all of the bits
            ' so the 1's become 0's (other bits are ignored)
            mask ^= core.IRQFLAGS_MASK
            writereg(core.IRQFLAGS1, 2, @mask)
    else
        return


PUB interrupt(): mask
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
    mask := 0
    readreg(core.IRQFLAGS1, 2, @mask)


PUB int_mask(mask=-2): curr_mask
' Set interrupt mask
'   Valid values:
'   Bits 15..0
'       11: RSSI exceeds rssi_int_thresh()
'       9: Valid preamble detected
'       8: Matching syncword (and address, if enabled) detected
'       4: FIFO has overrun
'       0: Battery voltage < low batt threshold
'   Any other value is ignored
    if ( mask & core.WR_CLR_BITS )
        writereg(core.IRQFLAGS1, 2, @mask)
    else
        return


PUB lna_gain(gain=-255): curr_gain
' Set LNA gain, in dB
'   Valid values: *0 (Maximum gain), -6, -12, -24, -36, -48
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting will have no effect if AGC is enabled
'   NOTE: The current setting returned may be different than what was
'       explicitly set, if the AGC is enabled
    curr_gain := 0
    readreg(core.LNA, 1, @curr_gain)
    case gain
        0, -6, -12, -24, -36, -48:
            gain := lookdown(gain: 0, -6, -12, -24, -36, -48) << core.LNAGAIN
            gain := ((curr_gain & core.LNAGAIN_MASK) | gain) & core.LNA_MASK
            writereg(core.LNA, 1, @curr_gain)
        other:
            curr_gain := (curr_gain >> core.LNAGAIN) & core.LNAGAIN_BITS
            return lookup(curr_gain: 0, -6, -12, -24, -36, -48)


PUB low_batt_lvl(lvl=-2): curr_lvl
' Set low battery threshold, in millivolts
'   Valid values:
'       1695, 1764, *1835, 1905, 1976, 2045, 2116, 2185
'   Any other value polls the chip and returns the current setting
    curr_lvl := 0
    readreg(core.LOWBAT, 1, @curr_lvl)
    case lvl
        1695, 1764, 1835, 1905, 1976, 2045, 2116, 2185:
            lvl := lookdownz(lvl: 1695, 1764, 1835, 1905, 1976, 2045, 2116, 2185)
            lvl := ((curr_lvl & core.LOWBATTRIM_MASK) | lvl)
            writereg(core.LOWBAT, 1, @lvl)
        other:
            curr_lvl &= core.LOWBATTRIM_BITS
            return lookupz(curr_lvl: 1695, 1764, 1835, 1905, 1976, 2045, 2116, 2185)


PUB low_batt_mon_ena(state=-2): curr_state
' Enable low battery detector signal
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core.LOWBAT, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core.LOWBATON
            state := ((curr_state & core.LOWBAT_MASK) | state)
            writereg(core.LOWBAT, 1, @state)
        other:
            return (((curr_state >> core.LOWBATON) & 1) == 1)


PUB low_freq_mode(state=-2): curr_state
' Enable Low frequency-specific register access
'   Valid values:
'       TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core.OPMODE, 1, @curr_state)
    case ||(state)
        0, 1:
            state := (||(state) << core.LOWFREQMODEON)
            state := ((curr_state & core.LOWFREQMODEON_MASK) | state)
            writereg(core.OPMODE, 1, @state)
        other:
            return ((curr_state >> core.LOWFREQMODEON) & 1) == 1


PUB manchest_enc_ena(state=-2): curr_state
' Enable Manchester encoding/decoding
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting and data_whiten_ena() are mutually exclusive;
'       enabling this will disable data_whiten_ena()
    curr_state := 0
    readreg(core.PKTCFG1, 1, @curr_state)
    case ||(state)
        0:                                      ' disabled state is just 0, so
        1:                                      '   just leave it as-is
            state := DCFREE_MANCH << core.DCFREE
        other:
            curr_state := ((curr_state >> core.DCFREE) & core.DCFREE_BITS)
            return (curr_state == DCFREE_MANCH)

    state := ((curr_state & core.DCFREE_MASK) | state)
    writereg(core.PKTCFG1, 1, @state)


PUB modulation(mode=-2): curr_mode | lr_mode, opmode_orig
' Set modulation type
'   Valid values:
'      *FSK (0): FSK packet radio mode
'       OOK (1): OOK packet radio mode
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core.OPMODE, 1, @curr_mode)
    opmode_orig := (curr_mode & core.MODE_BITS) ' cache user's current opmode
    case mode
        FSK, OOK:
            mode <<= core.MODTYPE
            ' set operating mode to SLEEP (required to change the LORAMODE bit)
            mode := (curr_mode & core.MODE_MASK & core.MODTYPE_MASK) | mode
            writereg(core.OPMODE, 1, @mode)

            time.usleep(core.T_POR)                     ' wait for chip to be ready
            opmode(opmode_orig)                         ' restore user's opmode
        other:
            return ((curr_mode >> core.MODTYPE) & core.MODTYPE_BITS)


PUB node_addr(addr=-2): curr_addr
' Set node address
'   Valid values: $00..$FF
'   Any other value polls the chip and returns the current setting
    case addr
        $00..$FF:
            writereg(core.NODEADDR, 1, @addr)
        other:
            curr_addr := 0
            readreg(core.NODEADDR, 1, @curr_addr)
            return


PUB ocp_current(level=-2): curr_lvl
' Trim over-current protection, to milliamps
'   Valid values: 45..240mA
'   Any other value polls the chip and returns the level setting
    curr_lvl := 0
    readreg(core.OCP, 1, @curr_lvl)
    case level
        45..120:
            level := (level - 45) / 5
        130..240:
            level := (level - -30) / 10
        other:
            curr_lvl := curr_lvl & core.OCPTRIM
            case curr_lvl
                0..15:
                    return 45 + 5 * curr_lvl
                16..27:
                    return -30 + 10 * curr_lvl
                28..31:
                    return 240
            return

    level := ((curr_lvl & core.OCPTRIM_MASK) | level)
    writereg(core.OCP, 1, @level)


PUB oc_protect_ena(state=-2): curr_state
' Enable over-current protection for PA
'   Valid values:
'      *TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core.OCP, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core.OCPON
            state := ((curr_state & core.OCPON_MASK) | state) & core.OCP_MASK
            writereg(core.OCP, 1, @state)
        other:
            return (((curr_state >> core.OCPON) & 1) == 1)


PUB opmode(mode=-2): curr_mode | modemask
' Set device operating mode
'   Valid values:
'       SLEEPMODE (%000): Sleep
'      *STDBY (%001): Standby
'       FSTX (%010): Frequency synthesis TX
'       TX (%011): Transmit
'       FSRX (%100): Frequency synthesis RX
'       RXCONT (%101): Receive continuous
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core.OPMODE, 1, @curr_mode)
    case mode
        SLEEPMODE..RXCONT:
            mode := ((curr_mode & core.MODE_MASK) | mode)
            writereg(core.OPMODE, 1, @mode)
        other:
            return curr_mode & core.MODE_BITS


PUB pa_ramp_time(ramptime=-2): curr_time
' Set Rise/fall time of FSK ramp up/down, in microseconds
'   Valid values: 3400, 2000, 1000, 500, 250, 125, 100, 62, 50, *40, 31, 25, 20, 15, 12, 10
'   Any other value polls the chip and returns the current setting
    curr_time := 0
    readreg(core.PARAMP, 1, @curr_time)
    case ramptime
        3400, 2000, 1000, 500, 250, 125, 100, 62, 50, 40, 31, 25, 20, 15, 12, 10:
            ramptime := lookdownz(ramptime: 3400, 2000, 1000, 500, 250, 125, 100, 62, 50, 40, ...
                                            31, 25, 20, 15, 12, 10)
            ramptime := ((curr_time & core.PA_RAMP_MASK) | ramptime)
            writereg(core.PARAMP, 1, @ramptime)
        other:
            curr_time &= core.PA_RAMP_BITS
            return lookupz(curr_time:   3400, 2000, 1000, 500, 250, 125, 100, 62, 50, 40, 31, ...
                                        25, 20, 15, 12, 10)


PUB payld_len(len=-2): curr_len
' Set payload length, in bytes
'   Valid values: 1..64 (FSK/OOK)
'   Any other value polls the chip and returns the current setting
    curr_len := 0
    readreg(core.PKTCFG2, 2, @curr_len)
    if ( lookdown(len: 1..64) )
        len := ((curr_len & core.PAYLDLEN_MASK) | len)
        writereg(core.PKTCFG2, 2, @len)
    else
        return (curr_len & core.PAYLDLEN_BITS)


PUB payld_len_cfg(mode=-2): curr_mode
' Set payload length configuration/mode
'   Valid values:
'       PKTLEN_FIXED (0): Fixed-length payload
'      *PKTLEN_VAR (1): Variable-length payload
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core.PKTCFG1, 1, @curr_mode)
    case mode
        0, 1:
            mode <<= core.PKTFORMAT
            mode := ((curr_mode & core.PKTFORMAT_MASK) | mode)
            writereg(core.PKTCFG1, 1, @mode)
        other:
            return ((curr_mode >> core.PKTFORMAT) & 1)


PUB payld_rdy(): flag
' Flag indicating payload received/ready
'   Returns:
'       TRUE (-1): payload ready
'       FALSE (0): no payload received
'   NOTE: Once set, this flag clears when FIFO is emptied
    return ((interrupt() & INT_PAYLDREADY) == INT_PAYLDREADY)


PUB payld_sent(): flag
' Flag indicating payload sent
'   Returns:
'       TRUE (-1): payload sent
'       FALSE (0): payload not sent
'   NOTE: Once set, this flag clears when exiting TX mode
    return ((interrupt() & INT_PACKETSENT) == INT_PACKETSENT)


PUB pll_locked(): flag
' Return PLL lock status, while attempting a TX, RX, or CAD operation
'   Returns:
'       0: PLL didn't lock
'       1: PLL locked


PUB preamble_len(length=-2):  curr_len
' Set preamble length, in bytes
'   Valid values: 0..65535 (default: 3)
'   Any other value polls the chip and returns the current setting
    case length
        0..65535:
            writereg(core.PREAMBLEMSB, 2, @length)
        other:
            curr_len := 0
            readreg(core.PREAMBLEMSB, 2, @curr_len)
            return curr_len


PUB rc_osc_cal(state=-2): curr_state
' Trigger calibration of RC oscillator
'   Valid values:
'       TRUE (-1 or 1)
'   Any other value is ignored
    curr_state := 0
    readreg(core.OSC, 1, @curr_state)
    case ||(state)
        1:
            state := ||(state) << core.RCCALSTART
            state := (curr_state & core.RCCALSTART_MASK | state)
            writereg(core.OSC, 1, @state)
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


PUB rssi(): val
' Current RSSI, in dBm
    val := 0
    readreg(core.RSSIVALUE, 1, @val)
    return -(val / 2)


PUB rssi_int_thresh(thresh=-255): curr_thr
' Set threshold for triggering RSSI interrupt, in dBm
'   Valid values: -127..0
'   Any other value polls the chip and returns the current setting
    case thresh
        -127..0:
            thresh := ||(thresh) * 2
            writereg(core.RSSITHRESH, 1, @thresh)
        other:
            curr_thr := 0
            readreg(core.RSSITHRESH, 1, @curr_thr)
            return -(curr_thr / 2)


PUB rx_bw(bw=-2): curr_bw | exp_mod, exp, mant, mant_tmp, rxb_calc
' Set receive bandwidth, in Hz (* single side-band)
'   Valid values:
'       2604, 3125, 3906, 5208, 6250, 7812, 10416, 12500, 15625,
'       20833, 25000, 31250, 41666, 50000, 62500, 83333, 100000, 125000,
'       166666, 200000, 250000, 333333, 400000, 500000
'   Any other value polls the chip and returns the current setting
'   NOTE: In the 169MHz band, 250_000 and 500_000 are not supported
    curr_bw := 0
    readreg(core.RXBW, 1, @curr_bw)
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
            bw := ((curr_bw & core.RX_BW_MASK) | bw)
            writereg(core.RXBW, 1, @bw)
        other:
            exp := (curr_bw & core.RXBWEXP_BITS)
            mant := ((curr_bw >> core.RXBWMANT) & core.RXBWMANT_BITS)
            mant := lookupz(mant: 16, 20, 24)
            return (FXOSC / (mant * (1 << (exp + exp_mod))))


PUB rx_mode()
' Change chip state to RX (receive)
    opmode(RXCONT)


PUB rx_payld(nr_bytes, ptr_buff)
' Receive data from RX FIFO into buffer at ptr_buff
'   Valid values: nr_bytes - 1..64
'   Any other value is ignored
    case nr_bytes
        1..64:
            readreg(core.FIFO, nr_bytes, ptr_buff)
        other:
            return


PUB sleep()
' Power down chip
    opmode(SLEEPMODE)


PUB set_syncwd(ptr_syncwd)
' Set sync word
'   ptr_syncwd: pointer to copy syncword data from
'   NOTE: 8 bytes will be read from ptr_syncwd
    writereg(core.SYNCVALUE1, 8, ptr_syncwd)


PUB syncwd(ptr_buff): ptr_syncwd
' Get current sync word
'   ptr_syncwd: pointer to copy syncword data to
'   NOTE: Variable pointed to by ptr_buff must be at least 8 bytes in length
    readreg(core.SYNCVALUE1, 8, ptr_syncwd)


PUB syncwd_ena(state=-2): curr_state
' Enable sync word generation (TX) and detection (RX)
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core.SYNCCFG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core.SYNCON
            state := ((curr_state & core.SYNCON_MASK) | state)
            writereg(core.SYNCCFG, 1, @state)
        other:
            return (((curr_state >> core.SYNCON) & 1) == 1)


PUB syncwd_len(length=-2): curr_len
' Set length of sync word, in bytes
'   Valid values: 1..8
'   Any other value polls the chip and returns the current setting
    curr_len := 0
    readreg(core.SYNCCFG, 1, @curr_len)
    case length
        1..8:
            length := (length-1) << core.SYNCSZ
            length := ((curr_len & core.SYNCSZ_MASK) | length)
            writereg(core.SYNCCFG, 1, @length)
        other:
            return (((curr_len >> core.SYNCSZ) & core.SYNCSZ_BITS) + 1)


PUB tx_mode()
' Change chip state to transmit
    opmode(TX)


PUB tx_payld(nr_bytes, ptr_buff)
' Queue data to be transmitted in the TX FIFO
'   nr_bytes Valid values: 1..64
'   Any other value is ignored
    case nr_bytes
        1..64:
            writereg(core.FIFO, nr_bytes, ptr_buff)
        other:
            return


PUB tx_pwr(pwr=-255): curr_pwr | pa_dac
' Set transmit power, in dBm
'   Valid values:
'       -1..14 (when tx_sig_routing() == RFO)
'       5..23 (when tx_sig_routing() == PABOOST)
'   Any other value polls the chip and returns the current setting
    curr_pwr := pa_dac := 0
    readreg(core.PACFG, 1, @curr_pwr)
    readreg(core.PADAC, 1, @pa_dac)
    case _txsig_routing
        RFO:
            case pwr
                -1..14:
                    curr_pwr := (7 << core.MAXPWR) | (pwr + 1)
                other:
                    return (curr_pwr & core.OUTPUTPWR_BITS) - 1
            writereg(core.PACFG, 1, @curr_pwr)
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
                            return (curr_pwr & core.OUTPUTPWR_BITS) + 5
                        core.PA_BOOST:
                            return (curr_pwr & core.OUTPUTPWR_BITS) + 8
                        other:
                            return pa_dac
                    return
            curr_pwr := (1 << core.PASELECT) | (pwr - 5)
            writereg(core.PADAC, 1, @pa_dac)
            writereg(core.PACFG, 1, @curr_pwr)
        other:
            return (curr_pwr & core.OUTPUTPWR_BITS) - 1


PUB tx_sig_routing(pin=-2): curr_pin
' Set transmit signal output routing
'   Valid values:
'      *RFO (0): Signal routed to RFO pin, max power is +14dBm
'       PABOOST (128): Signal routed to PA_BOOST pin, max power is +23dBm
'   NOTE: This has a direct effect on the maximum output power available
'       using the tx_pwr() method
    case pin
        RFO, PABOOST:
            _txsig_routing := pin
        other:
            return _txsig_routing


PUB tx_start_cond(cond=-2): curr_cond
' Define condition required to begin packet transmission
'   Valid values:
'       TXSTART_FIFOLVL (0): If the number of bytes in the FIFO exceeds
'           fifo_int_thresh()
'      *TXSTART_FIFONOTEMPTY (1): If there's at least one byte in the FIFO
'   Any other value polls the chip and returns the current setting
    curr_cond := 0
    readreg(core.FIFOTHRESH, 1, @curr_cond)
    case cond
        TXSTART_FIFOLVL, TXSTART_FIFONOTEMPTY:
            cond <<= core.TXSTARTCOND
            cond := ((curr_cond & core.TXSTARTCOND_MASK) | cond)
            writereg(core.FIFOTHRESH, 1, @cond)
        other:
            return ((curr_cond >> core.TXSTARTCOND) & 1)


PRI readreg(reg_nr, nr_bytes, ptr_buff) | tmp
' Read nr_bytes from device into ptr_buff
    case reg_nr                                 ' validate register #
        $00..$16, $1A..$42, $44..$4D, $5B, $5D, $61..$64, $70:
        other:
            return

    outa[_CS] := 0
        spi.wr_byte(reg_nr)
        spi.rdblock_msbf(ptr_buff, nr_bytes)        ' read MS-byte first
    outa[_CS] := 1


PRI writereg(reg_nr, nr_bytes, ptr_buff) | tmp
' Write nr_bytes from ptr_buff to device
    case reg_nr                                 ' validate register #
        $00..$10, $12..$16, $1A..$3B, $3D..$41, $44..$4D, $5D, $61..$64, $70:
        other:
            return

    outa[_CS] := 0
        spi.wr_byte(reg_nr | core.SPI_WR)           ' must set WNR bit to write
        spi.wrblock_msbf(ptr_buff, nr_bytes)        ' write MS-byte first
    outa[_CS] := 1


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

