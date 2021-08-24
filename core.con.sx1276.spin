{
    --------------------------------------------
    Filename: core.con.sx1276.spin
    Author: Jesse Burt
    Description: Low-level constants
    Copyright (c) 2021
    Started Oct 6, 2019
    Updated Aug 24, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

' SPI Configuration
    SCK_MAX_FREQ                = 10_000_000
    SPI_MODE                    = 0

    T_POR                       = 10_000        ' usec
    T_RESACTIVE                 = 100
    T_RES                       = 5_000

    SPI_WR                      = 1 << 7        ' wnr bit (Write access)

' Registers
    FIFO                        = $00

    OPMODE                      = $01
    OPMODEF_MASK                = $EF           ' chip in FSK/OOK mode
        LORAMODE                = 7
        MODTYPE                 = 5
        LOWFREQMODEON           = 3
        MODE                    = 0
        MODTYPE_BITS            = %11
        MODE_BITS               = %111
        LORAMODE_MASK           = (1 << LORAMODE) ^ OPMODEF_MASK
        MODTYPE_MASK            = (MODTYPE_BITS << MODTYPE) ^ OPMODEF_MASK
        LOWFREQMODEON_MASK      = (1 << LOWFREQMODEON) ^ OPMODEF_MASK
        MODE_MASK               = MODE_BITS ^ OPMODEF_MASK

    FRFMSB                      = $06
    FRFMID                      = $07
    FRFLSB                      = $08

    PACFG                       = $09
    PACFG_MASK                  = $FF
        PASELECT                = 7
        MAXPWR                  = 4
        OUTPUTPWR               = 0
        MAXPWR_BITS             = %111
        OUTPUTPWR_BITS          = %1111
        PASELECT_MASK           = (1 << PASELECT) ^ PACFG_MASK
        MAXPWR_MASK             = (MAXPWR_BITS << MAXPWR) ^ PACFG_MASK
        OUTPUTPWR_MASK          = OUTPUTPWR_BITS ^ PACFG_MASK

    PARAMP                      = $0A
    PARAMP_MASK                 = $0F
        PA_RAMP                 = 0
        PA_RAMP_BITS            = %1111

    OCP                         = $0B
    OCP_MASK                    = $3F
        OCPON                   = 5
        OCPTRIM                 = 0
        OCPTRIM_BITS            = %11111
        OCPON_MASK              = (1 << OCPON) ^ OCP_MASK
        OCPTRIM_MASK            = OCPTRIM_BITS ^ OCP_MASK

    LNA                         = $0C
    LNA_MASK                    = $FB
        LNAGAIN                 = 5
        LNABOOSTLF              = 3
        LNABOOSTHF              = 0
        LNAGAIN_BITS            = %111
        LNABOOSTLF_BITS         = %11
        LNABOOSTHF_BITS         = %11
        LNAGAIN_MASK            = (LNAGAIN << LNAGAIN) ^ LNA_MASK
        LNABOOSTLF_MASK         = (LNABOOSTLF << LNABOOSTLF) ^ LNA_MASK
        LNABOOSTHF_MASK         = LNABOOSTHF_BITS ^ LNA_MASK

    DIOMAP1                     = $40
    DIOMAP1_MASK                = $FF
        DIO0MAP                 = 6
        DIO1MAP                 = 4
        DIO2MAP                 = 2
        DIO3MAP                 = 0
        DIO0MAP_MASK            = (1 << DIO0MAP) ^ DIOMAP1_MASK
        DIO1MAP_MASK            = (1 << DIO1MAP) ^ DIOMAP1_MASK
        DIO2MAP_MASK            = (1 << DIO2MAP) ^ DIOMAP1_MASK
        DIO3MAP_MASK            = 1 ^ DIOMAP1_MASK

    DIOMAP2                     = $41
    DIOMAP2_MASK                = $F1
        DIO4MAP                 = 6
        DIO5MAP                 = 4
        DIO4MAP_MASK            = (1 << DIO4MAP) ^ DIOMAP2_MASK
        DIO5MAP_MASK            = (1 << DIO5MAP) ^ DIOMAP2_MASK

    VERSION                     = $42
    TCXO                        = $4B

    PADAC                       = $4D
    PADAC_MASK                  = $07
        PADAC_RSVD              = 3
        PADAC_RSVD_BITS         = %11111
        PADAC_RSVD_DEF          = $10 < PADAC_RSVD
        PA_DAC                  = 0
        PA_DAC_BITS             = %111
        PA_DEF                  = %100
        PA_BOOST                = %111

    FORMERTEMP                  = $5B
    AGCREF                      = $61
    AGCTHRESH1                  = $62
    AGCTHRESH2                  = $63
    AGCTHRESH3                  = $64

' FSK/OOK-specific functionality
    BITRATEMSB                  = $02
    BITRATELSB                  = $03
    FDEVMSB                     = $04
    FDEVLSB                     = $05
    RXCFG                       = $0D
    RSSICFG                     = $0E
    RSSICOLLISION               = $0F
    RSSITHRESH                  = $10
    RSSIVALUE                   = $11

    RXBW                        = $12
    RXBW_MASK                   = $1F
        RXBWMANT                = 3
        RXBWEXP                 = 0
        RX_BW                   = 0
        RXBWMANT_BITS           = %11
        RXBWEXP_BITS            = %111
        RX_BW_BITS              = %11111
        RXBWMANT_MASK           = (RXBWMANT_BITS << RXBWMANT) ^ RXBW_MASK
        RXBWEXP_MASK            = (RXBWEXP_BITS << RXBWEXP) ^ RXBW_MASK
        RX_BW_MASK              = RX_BW_BITS ^ RXBW_MASK

    AFCBW                       = $13
    OOKPEAK                     = $14
    OOKFIX                      = $15
    OOKAVG                      = $16
' $17..$19 - RESERVED
    AFCFEI                      = $1A
    AFCMSB                      = $1B
    AFCLSB                      = $1C
    FEIMSB                      = $1D
    FEILSB                      = $1E
    PREAMBLEDETECT              = $1F
    RXTIMEOUT1                  = $20
    RXTIMEOUT2                  = $21
    RXTIMEOUT3                  = $22
    RXDELAY                     = $23

    OSC                         = $24
    OSC_MASK                    = $0F
        RCCALSTART              = 3
        CLKOUT                  = 0
        CLKOUT_BITS             = %111
        RCCALSTART_MASK         = (1 << RCCALSTART) ^ OSC_MASK
        CLKOUT_MASK             = CLKOUT_BITS ^ OSC_MASK

    PREAMBLEMSB                 = $25
    PREAMBLELSB                 = $26
    SYNCCFG                     = $27
    SYNCVALUE1                  = $28
    SYNCVALUE2                  = $29
    SYNCVALUE3                  = $2A
    SYNCVALUE4                  = $2B
    SYNCVALUE5                  = $2C
    SYNCVALUE6                  = $2D
    SYNCVALUE7                  = $2E
    SYNCVALUE8                  = $2F

    PACKETCFG1                  = $30
    PACKETCFG1_MASK             = $FF
        PACKETFORMAT            = 7
        DCFREE                  = 5
        CRCON                   = 4
        CRCAUTOCLROFF           = 3
        ADDRFILT                = 1
        CRCWHTNTYPE             = 0
        DCFREE_BITS             = %11
        ADDRFILT_BITS           = %11
        PACKETFORMAT_MASK       = (1 << PACKETFORMAT) ^ PACKETCFG1_MASK
        DCFREE_MASK             = (DCFREE_BITS << DCFREE) ^ PACKETCFG1_MASK
        CRCON_MASK              = (1 << CRCON) ^ PACKETCFG1_MASK
        CRCAUTOCLROFF_MASK      = (1 << CRCAUTOCLROFF) ^ PACKETCFG1_MASK
        ADDRFILT_MASK           = (ADDRFILT_BITS << ADDRFILT) ^ PACKETCFG1_MASK
        CRCWHTNTYPE_MASK        = 1 ^ PACKETCFG1_MASK

    PACKETCFG2                  = $31
    PACKETCFG2_MASK             = $7F
        DATAMODE                = 6
        IOHOMEON                = 5
        IOHOMEPWRFRM            = 4
        BEACONON                = 3
        PAYLDLEN_MSB            = 0
        DATAMODE_MASK           = (1 << DATAMODE) ^ PACKETCFG2_MASK
        IOHOMEON_MASK           = (1 << IOHOMEON) ^ PACKETCFG2_MASK
        IOHOMEPWRFRM_MASK       = (1 << IOHOMEPWRFRM) ^ PACKETCFG2_MASK
        BEACONON_MASK           = (1 << BEACONON) ^ PACKETCFG2_MASK

    PAYLDLENGTH                 = $32
    PKTCFG2_PAYLDLEN_MASK       = $7FFF         ' pseudo-mask: $31 and $32
        PAYLDLEN_BITS           = %111_11111111 ' bits from both regs
        PAYLDLEN_MASK           = PAYLDLEN_BITS ^ PKTCFG2_PAYLDLEN_MASK

    NODEADRS                    = $33
    BROADCASTADRS               = $34
    FIFOTHRESH                  = $35
    SEQCFG1                     = $36
    SEQCFG2                     = $37
    TIMERRESOL                  = $38
    TIMER1COEF                  = $39
    TIMER2COEF                  = $3A
    IMAGECAL                    = $3B
    TEMP                        = $3C
    LOWBAT                      = $3D

    IRQFLAGS1                   = $3E
    IRQFLAGS2                   = $3F
    IRQFLAGS_MASK               = $FFFF
        WR_CLR_BITS             = %0000_1011_0001_0001

    PLLHOP                      = $44
    BITRATEFRAC                 = $5D

PUB Null{}
' This is not a top-level object

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
