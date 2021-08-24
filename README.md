# sx1276-spin
-------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the Semtech SX1276 LoRa/FSK/OOK transceiver.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

**NOTE**: This driver only provides support for FSK and OOK modulation. For LoRa modulation support, see [sx1276-lora-spin](https://github.com/avsa242/sx1276-lora-spin)

## Salient Features

* SPI connection at up to 1MHz (P1), 10MHz (P2)
* Change transceiver frequency to anything within the SX1276's tunable range
* Change common transceiver settings, such as: bandwidth, payload length, LNA gain, transmit power
* Change device operating mode
* Configure GPIO pins ("DIO#")
* Read live RSSI

## Requirements

P1/SPIN1:
* spin-standard-library
* P1: 1 extra core/cog for the PASM SPI engine

P2/SPIN2:
* p2-spin-standard-library

## Compiler Compatibility

* P1/SPIN1: OpenSpin (tested with 1.00.81)
* P2/SPIN2: FlexSpin (tested with 6.0.0)
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* Very early in development - may malfunction, or outright fail to build

## TODO

- [ ] TBD

