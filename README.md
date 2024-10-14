# sx1276-spin
-------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the Semtech SX1276 LoRa/FSK/OOK transceiver (FSK/OOK mode only).

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

**NOTE**: This driver only provides support for FSK and OOK modulation. For LoRa modulation support, see [sx1276-lora-spin](https://github.com/avsa242/sx1276-lora-spin)


## Salient Features

* SPI connection at 1MHz (P1), up to 10MHz (P2)
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

| Processor | Language | Compiler               | Backend      | Status                |
|-----------|----------|------------------------|--------------|-----------------------|
| P1        | SPIN1    | FlexSpin (6.9.4)       | Bytecode     | OK                    |
| P1        | SPIN1    | FlexSpin (6.9.4)       | Native/PASM  | OK                    |
| P2        | SPIN2    | FlexSpin (6.9.4)       | NuCode       | Untested              |
| P2        | SPIN2    | FlexSpin (6.9.4)       | Native/PASM2 | OK                    |

(other versions or toolchains not listed are __not supported__, and _may or may not_ work)


## Limitations

* Doesn't support LoRa modulation (see note above)

