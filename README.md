# Assembly Code for it-Stores

This repository contains Assembly code (MPASM) I wrote in the Spring of 2009 for a 14-week-long design course (AER201H1S) undertaken with [two very talented classmates](http://aer201.aerospace.utoronto.ca/History/team.aspx?ID=1&Team=40&Project=Project3&Year=2009) as part of the second-year Engineering Science curriculum at the University of Toronto.

The project required presenting a proof-of-concept prototype for an automated storage system consisting of five separate storage modules with configurable user access, powered by a standard 110-V 60-Hz 3-pin AC outlet and a back-up rechargeable DC power supply. The system was designed so that an administrator could electronically configure user access through a control module. If a user subsequently submits valid credentials, the system provides an unlock signal to the solenoid used in the corresponding storage module's locking mechanism. See [project](project) for more details.

My contribution was to program a microcontroller unit (PIC16F877 from MicroChip) connected to a 16-character 2-line 5x8-pixel LCD display (controlled by Hitachi’s HD44780 Driver IC), a 4x4 matrix keypad (MM74C922 from National Semiconductor) and a DS1307 RTC Chip (Dallas Semiconductor). During runtime, code resides in Flash ROM, RAM is used to store temporary variables, while activity logs and other account information are stored in EEPROM. See [doc](doc) for more information.

The source code is in [src](src) and was developed in MPLAB IDE v8.10. The header file for the PIC provided by the manufacturer is in [inc](inc).