;#############################################################################
;
;	Lathe DRO control for chineese DRO scale
;	Read raidus and length
;	Display on 2 TM1637 6-digits 7-segments
;	Input with 4x4 keypad trough 74LS164 as https://hackaday.com/2015/04/15/simple-keypad-scanning-with-spi-and-some-hardware/
;
;#############################################################################
;
;	Version 1b
;	Basic 2 DRO scale sampling, display on TM1637
;	Convert DRO0 from radius to diameter
;	Convert from MM to INCHES (0.001)
;	Output on UART at 9600 bauds
;
;;#############################################################################
;
;	radius to diameter
;	MM to IN
;	Invert direction done in software or dip switches
;	Set actual
;	Zero
;	Half function for mill 
;	
;	Test at 8MHz
;	?Upgrade to 20MHz crystal if enough pins avaiable
;	?Upgrade to 16F1459
;
;      7   8   9   X
;      4   5   6   Y
;      1   2   3   
;      U   0       OK
;
;      7   8   9   X
;      4   5   6   Y
;      1   2   3   Z
;      U   0  1/2  OK
;
;	select U to switch between IN and MM
;
;	select Axis
;	display 0
;  	  select OK to set to 0
;	  select any Axis to cancel
;
;	select Axis
;	display 0
;	  enter actual
;	    select OK to set to actual
;	    select any Axis to cancel
;
;	select Axis
;	display 0
;	  select 1/2
;	  display actual / 2
;	    select OK to set to 1/2
;	    select any Axis to cancel
;
;
;#############################################################################
;
; Chineese DRO scale pinout
; USB mini B connector with fake pinout:
; Pin 1 (USB standard: VBUS RED)		Data
; Pin 2 (USB standard: DATA- WHITE)		Clock
; Pin 3 (USB standard: DATA+ GREEN)		Ground
; Pin 4 (USB standard: NC on device side)	Power 1.5V-3.0V
; Pin 5 (USB standard: GROUND BLACK)		NC
; low of more than 0.5 ms is idle between 2 data packets
; 24 bit sync, LSB first, in 0.01 mm
; bit 20 is sign, max data is 20bits, or 10485.75mm
; 1.5V signal inverted trough NPN with 33K pullup and 1K between base and "USB" connector
;
;#############################################################################
;
; TM1637 header:
; VCC
; GND
; DIO
; CLK
; "i2c" open collector protocol but no address and LSB first
; remove 2 line cap
; PIC outputs pass trough a PN2222 transistor to sink signal to ground:
; PIC to base
; emitter to ground
; TM1637 to collector
;
;#############################################################################

	LIST	p=16F88			; processor model
#INCLUDE	<P16F88.INC>		; processor specific variable definitions
#INCLUDE	<PIC16F88_Macro.asm>	; base macro for banks, context, branchs
#INCLUDE	<PIC16F88_MacroExt.asm> ; 16/24/32 bit instructions extensions
	ERRORLEVEL -302		; suppress "bank" warnings
;MPASMx /c- /e+ /m+ /pPIC16F88 /rDEC ..\PIC16F88\DRO_Lathe_1b.asm
	
;#############################################################################
;	Configuration
;#############################################################################

	__CONFIG	_CONFIG1, 	_CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & _WDT_OFF & _INTRC_IO
	__CONFIG	_CONFIG2, 	_IESO_OFF & _FCMEN_OFF

;#############################################################################
;	Pinout
;#############################################################################

; PIC16F88:
; pin  1 IOA PORTA2	I DRO0 CLOCK
; pin  2 IOA PORTA3	I DRO0 DATA
; pin  3 IOA PORTA4	I Switch MM/IN
; pin  4 I__ PORTA5	MCLR (VPP)	; TODO change to keypad input
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O DISP Clock 
; pin  7 IO_ PORTB1	O DISP0 Data
; pin  8 IOR PORTB2	I UART RX
; pin  9 IO_ PORTB3	O DISP1 Data

; pin 10 IO_ PORTB4	
; pin 11 IOT PORTB5	O UART TX
; pin 12 IOA PORTB6	I ICSP PGC
; pin 13 IOA PORTB7	I ICSP PGD
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O ISR Status Bit
; pin 16 I_X PORTA7	
; pin 17 IOA PORTA0	I DRO1 CLOCK
; pin 18 IOA PORTA1	I DRO1 DATA


; V+ (square pad)
; Clock
; E
; Data
; GND

#DEFINE pin_DRO1_CLOCK	PORTA, 0 ; TODO convert to masks and bit test with generic routine
#DEFINE pin_DRO1_DATA		PORTA, 1
#DEFINE pin_DRO0_CLOCK	PORTA, 2
#DEFINE pin_DRO0_DATA		PORTA, 3
#DEFINE pin_switch_U		PORTA, 4
;#DEFINE MCLR			PORTA, 5
#DEFINE pin_ISR		PORTA, 6
;#DEFINE		PORTA, 7

#DEFINE pin_Disp_CLOCK	PORTB, 0
#DEFINE pin_Disp0_DATA	PORTB, 1
;#DEFINE UART RX		PORTB, 2
#DEFINE pin_Disp1_DATA	PORTB, 3

;#DEFINE 		PORTB, 4
#DEFINE pin_UART_TX		PORTB, 5
;#DEFINE PGC			PORTB, 6
;#DEFINE PGD			PORTB, 7

; EEPROM data byte at 0x00 is config
; bit 0-3 x2 axis 0-3 (for radius to diameter direct reading)
; bit 4-7 is reverse axis direction


;#############################################################################
;	Memory Organisation
;#############################################################################

; Bank #    SFR           GPR               SHARED GPR's			total 368 bytes of GPR, 16 shared between banks
; Bank 0    0x00-0x1F     0x20-0x7F         target area 0x70-0x7F		96
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  			80 + 16 shared with bank 0
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F			16 + 80 + 16 shared with bank 0
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF			16 + 80 + 16 shared with bank 0

;#############################################################################
;	File Variables and Constants
;#############################################################################
; Bank 0

CFG			EQU	0x60
WAIT_loopCounter1	EQU	0x21
WAIT_loopCounter2	EQU	0x22
WAIT_loopCounter3	EQU	0x23
loop_count		EQU	0x24
loop_count_2		EQU	0x25

; raw data
data_f			EQU	0x40
data_0			EQU	0x41
data_1			EQU	0x42
data_2			EQU	0x43

accum_0			EQU	0x44
accum_1			EQU	0x45
accum_2			EQU	0x46

data_status		EQU	0x48 
;0 DRO0 sign
;1 DRO1 sign can be removed, useless
;2 
;3 
;4 current sign
;5 current unit (0:mm, 1:in)
;6 suppress digit 3
;7 suppress digit 4

input_last		EQU	0x49
;0 
;1 
;2 
;3 
;4 sign switch
;5 
;6 
;7 

; packed BCD of data for display
data_BCD0		EQU	0x4A
data_BCD1		EQU	0x4B
data_BCD2		EQU	0x4C
data_BCD3		EQU	0x4D; could be ignored
; max display length -99.999 inches
; max display length -999.99 mm (1 m)
; max of 20 bit 10485.75


;	EQU	0x50
;	EQU	0x51

disp_currentSetMask	EQU	0x50
disp_currentClearMask	EQU	0x51
disp_buffer		EQU	0x52
PORTB_buffer		EQU	0x53


; TM1637 line output masks:
#DEFINE ClockClear	b'11111110'
#DEFINE ClockSet	b'00000001'

#DEFINE Data0Clear	b'11111101'
#DEFINE Data0Set	b'00000010'

#DEFINE Data1Clear	b'11110111'
#DEFINE Data1Set	b'00001000'

;#DEFINE Data2Clear	b'11110111'
;#DEFINE Data2Set	b'00001000'

;#DEFINE Data3Clear	b'11101111'
;#DEFINE Data3Set	b'00010000'

; TM1637 commands:
#DEFINE _Data_Write		b'01000000'
#DEFINE _Address_C3H		b'11000011'
#DEFINE _Display_ON		b'10001000'

;#############################################################################
;
;	Macro definitions
;
;#############################################################################

Pin_Clk_UP	MACRO
	MOVLW	ClockClear
	ANDWF	PORTB_buffer, F
	ENDM

Pin_Clk_DOWN	MACRO	
	MOVLW	ClockSet
	IORWF	PORTB_buffer, F
	ENDM
	
Pin_Data_UP	MACRO
	MOVF	disp_currentClearMask, W
	ANDWF	PORTB_buffer, F
	ENDM	

Pin_Data_DOWN	MACRO
	MOVF	disp_currentSetMask, W
	IORWF	PORTB_buffer, F
	ENDM
	
Peek_PORTB	MACRO
	MOVF	PORTB, W
	MOVWF	PORTB_buffer
	ENDM
	
Update_PORTB	MACRO
	MOVF	PORTB_buffer, W
	MOVWF	PORTB
	CALL 	WAIT_5us
	ENDM
	
disp_select0	MACRO
	MOVLW	Data0Clear
	MOVWF	disp_currentClearMask
	MOVLW	Data0Set
	MOVWF	disp_currentSetMask
	ENDM
	
disp_select1	MACRO
	MOVLW	Data1Clear
	MOVWF	disp_currentClearMask
	MOVLW	Data1Set
	MOVWF	disp_currentSetMask
	ENDM
	
;SwitchData2	MACRO
	; MOVLW	Data2Clear
	; MOVWF	disp_currentClearMask
	; MOVLW	Data2Set
	; MOVWF	disp_currentSetMask
	; ENDM
	
; SwitchData3	MACRO
	; MOVLW	Data3Clear
	; MOVWF	disp_currentClearMask
	; MOVLW	Data3Set
	; MOVWF	disp_currentSetMask
	; ENDM

;#############################################################################
;	Reset Vector - Main Entry Point
;#############################################################################

	ORG	0x0000
RESET:
	GOTO	SETUP

;#############################################################################
;	Interrupt Vector - Interrupt Service Routine
;#############################################################################

	ORG	0x0004
ISR:
	BSF	pin_ISR
	STALL	; ISR trap, this code should not be reachable
	RETFIE

;#############################################################################
;	Initial Setup
;#############################################################################

SETUP:

	BANK1
	
	; init analog inputs
	CLRF	ANSEL		; all digital

	; init port directions
	CLRF	TRISA		; all outputs
	CLRF	TRISB		; all outputs
	
	BSF	pin_DRO0_CLOCK	; input
	BSF	pin_DRO0_DATA	; input
	BSF	pin_DRO1_CLOCK	; input
	BSF	pin_DRO1_DATA	; input
	
	BSF	pin_switch_U	; input

	; init osc 8MHz
	BCF	OSCCON, SCS0
	BCF	OSCCON, SCS1
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
SETUP_OSC:
	BTFSS	OSCCON, IOFS
	GOTO	SETUP_OSC
	
	; UART at 9600, 8 bits, async
	;BSF	TXSTA, CSRC	; not used in async - set as clock source master
	BCF 	TXSTA, TX9	; 8 bit tx
	BSF	TXSTA, TXEN	; enable tx
	BCF	TXSTA, SYNC	; async
	
	; set 9600 baud rate
	BSF 	TXSTA, BRGH	; high speed baud rate generator	
	MOVLW	51		; 9600 bauds
	MOVWF	SPBRG
	
	; timer 0
	BCF	OPTION_REG, T0CS ; on instruction clock
	BCF	OPTION_REG, PSA ; pre scaler assigned to tmr0
	BCF	OPTION_REG, PS2 ; 0
	BSF	OPTION_REG, PS1 ; 1
	BCF	OPTION_REG, PS0 ; 0 for 1:8 tmr0 ps
	; tmr0 overlfow every 8*256 instructions, or 2048 instructions / 1.024ms

	BCF	PIE1, TMR1IE	; TMR1 interrupt
	
	BANK0
	
	; ports
	CLRF	PORTA
	CLRF	PORTB	

	; timer1
	CLRF	TMR1L
	CLRF	TMR1H
	BCF	T1CON, T1CKPS0	; 0
	BSF	T1CON, T1CKPS1	; 1
	; pre scaler is 1:4, overlfow of 65536 instructions cycles is 131ms
	BCF	T1CON, TMR1CS	; timer1 clock is FOSC/4
	BSF	T1CON, TMR1ON	; timer1 ON
	
	; UART
	BSF	RCSTA, SPEN	; serial port enabled

	BCF	pin_ISR
	CLRF	input_last

; enable interrupts
	BCF	INTCON, PEIE ; enable peripheral int
	BCF	INTCON, TMR0IF; clear flag
	BCF	INTCON, TMR0IE; enable tmr0 interrupt
	CLRF	TMR0; clear tmr0

	BCF	INTCON, GIE
	
;#############################################################################
;	Main Loop
;#############################################################################
	MOVLW	HIGH (WAIT_50ms)
	MOVLW	PCLATH
	CALL WAIT_50ms
MAIN:
	MOVLW	'D'
	CALL	SEND_BYTE
	MOVLW	'R'
	CALL	SEND_BYTE
	MOVLW	'O'
	CALL	SEND_BYTE
	MOVLW	' '
	CALL	SEND_BYTE
	
	MOVLW	'T'
	CALL	SEND_BYTE
	MOVLW	'e'
	CALL	SEND_BYTE
	MOVLW	's'
	CALL	SEND_BYTE
	MOVLW	't'
	CALL	SEND_BYTE
	MOVLW	' '
	CALL	SEND_BYTE
	MOVLW	'1'
	CALL	SEND_BYTE
	MOVLW	'b'
	CALL	SEND_BYTE
	
	CALL	SEND_CRLF
	
	Peek_PORTB
	
	Pin_Clk_UP
	
	disp_select0
	Pin_Data_UP
	disp_select1
	Pin_Data_UP
	;SwitchData2
	;Pin_Data_UP
	;SwitchData3
	;Pin_Data_UP
	
	Update_PORTB
	
	
	disp_select0	
	Peek_PORTB
	CALL	TM1637_start
	
	MOVLW	_Data_Write
	MOVWF	disp_buffer	
	CALL	TM1637_data
	
	CALL	TM1637_stop
	
	CALL	TM1637_start
	
	MOVLW	_Address_C3H
	MOVWF	disp_buffer
	CALL	TM1637_data
	

	ARRAYl	table_hexTo7seg, 0
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	ARRAYl	table_hexTo7seg, 1
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	ARRAYl	table_hexTo7seg, 2
	MOVWF	disp_buffer
	CALL	TM1637_data

	ARRAYl	table_hexTo7seg, 3
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	ARRAYl	table_hexTo7seg, 4
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	ARRAYl	table_hexTo7seg, 5
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	CALL	TM1637_stop
	
	CALL	TM1637_start
	
	MOVLW	(_Display_ON | 4)
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	CALL	TM1637_stop
	
	disp_select1	
	Peek_PORTB
	CALL	TM1637_start
	
	MOVLW	_Data_Write
	MOVWF	disp_buffer	
	CALL	TM1637_data
	
	CALL	TM1637_stop
	
	CALL	TM1637_start
	
	MOVLW	_Address_C3H
	MOVWF	disp_buffer
	CALL	TM1637_data
	

	ARRAYl	table_hexTo7seg, 0x04
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	ARRAYl	table_hexTo7seg, 0x02
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	ARRAYl	table_hexTo7seg, 0x00
	MOVWF	disp_buffer
	CALL	TM1637_data

	ARRAYl	table_hexTo7seg, 0x02
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	ARRAYl	table_hexTo7seg, 0x0C
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	ARRAYl	table_hexTo7seg, 0x0E
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	CALL	TM1637_stop
	
	CALL	TM1637_start
	
	MOVLW	(_Display_ON | 4)
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	CALL	TM1637_stop
	
	
	; read config in eeprom
	
	BANKSEL	EEADR	; Select Bank of EEADR
	MOVLW	0x00	; Address const
	MOVWF	EEADR 	; Data Memory Address to read
	BANKSEL	EECON1 ; Select Bank of EECON1
	BCF	EECON1, EEPGD; Point to Data memory

	BSF 	EECON1, RD ; EE Read
	BANKSEL	EEDATA ; Select Bank of EEDATA
	MOVF	EEDATA, W ; W = EEDATA
	BANKSEL	CFG
	MOVWF	CFG

	MOVLW	'C'
	CALL	SEND_BYTE
	MOVLW	':'
	CALL	SEND_BYTE
	
	MOVLW	HIGH (table_nibbleHex)
	MOVWF	PCLATH
	
	SWAPF	CFG, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	CALL	SEND_BYTE
	
	MOVF	CFG, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	CALL	SEND_BYTE	
	
	CALL	SEND_CRLF
	
	
	
	CALL	WAIT_1s




LOOP:
	BTFSC	pin_switch_U	; check if pin is down
	GOTO	LOOP_input0
	
	BTFSC	input_last, 5	; check if already down
	GOTO	ACQ_DRO0
	
	; pin is down and wasn't already down
	MOVLW	0x20 		; bit 5 is units 0010 0000
	XORWF	data_status, F	; switch units sign
	BSF	input_last, 5	; mark as pressed down
	GOTO	ACQ_DRO0
	
LOOP_input0:
	BCF	input_last, 5	; reset pin pressed state
	
ACQ_DRO0:
	BSF	PORTB, 5
	; reset tmr1 for timeout
	CLRF	TMR1H
	CLRF	TMR1L
	BCF	PIR1, TMR1IF
ACQ_DRO0_0:
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO0_timeout
	
	BTFSC	pin_DRO0_CLOCK	; wait for clock low
	GOTO	ACQ_DRO0_0
	CLRF	TMR0		; clear tmr0
	BCF	INTCON, TMR0IF	; clear flag
ACQ_DRO0_1:

	BTFSC	pin_DRO0_CLOCK	; check if clock high
	GOTO	ACQ_DRO0_0	; reacquire if under 1ms of idle
	
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO0_timeout
	
	BTFSS	INTCON, TMR0IF
	GOTO	ACQ_DRO0_1

	CLRF	data_0
	CLRF	data_1
	CLRF	data_2
	
	CLRF	loop_count
	
READ_DRO0_loop1:
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO0_timeout
	
	BTFSS	pin_DRO0_CLOCK		;wait for clock up
	GOTO	READ_DRO0_loop1

READ_DRO0_loop2:
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO0_timeout
	
	BTFSC	pin_DRO0_CLOCK		; wait for clock down
	GOTO	READ_DRO0_loop2
	
	BTFSC	pin_DRO0_DATA		; bits are inverted in input level transistor
	GOTO	READ_DRO0_skip
	
	BSetc	data_0, loop_count
READ_DRO0_skip:
	INCF	loop_count, F
	CMP_lf	24, loop_count
	BR_NE	READ_DRO0_loop1
	
	BCF	PORTB, 5
	
	MOVLW	'0'
	CALL	SEND_BYTE
	MOVLW	' '
	CALL	SEND_BYTE
	CALL	SEND_DATA
	

	; read and apply cfg for DRO0
	
	BTFSS	CFG, 4		; invert sign 10001100
	GOTO	DRO0_noInvert	
	
	MOVLW	0x10
	XORWF	data_2, F
	
	; suppress - sign for 000000
	MOVF	data_0, F
	BTFSS	STATUS, Z
	GOTO	DRO0_noInvert
	MOVF	data_1, F
	BTFSS	STATUS, Z
	GOTO	DRO0_noInvert
	MOVF	data_2, F
	BTFSS	STATUS, Z
	GOTO	DRO0_noInvert	
	BCF	data_2, 4
	
DRO0_noInvert:	
	; save original sign for DRO0, and set actual for display
	BCF	data_status, 0
	BCF	data_status, 4
	BTFSS	data_2, 4
	GOTO	DRO0_noNeg
	BSF	data_status, 0
	BSF	data_status, 4
DRO0_noNeg:
	; clear sign from data packet
	BCF	data_2, 4

	; read config
	BTFSS	CFG, 0		; rad to dia 10001100
	GOTO	DRO0_noX2

 	BCF	STATUS, C
	RLF	data_0, F
	RLF	data_1, F
	RLF	data_2, F
	
DRO0_noX2:
	disp_select0; first display
	CALL	DISPLAYmm
	



	BTFSC	pin_switch_U	; check if pin is down
	GOTO	LOOP_input1
	
	BTFSC	input_last, 5	; check if already down
	GOTO	ACQ_DRO1
	
	; pin is down and wasn't already down
	MOVLW	0x20 		; bit 5 is units 0010 0000
	XORWF	data_status, F	; switch units sign
	BSF	input_last, 5	; mark as pressed down
	GOTO	ACQ_DRO1
	
LOOP_input1:
	BCF	input_last, 5	; reset pin pressed state




ACQ_DRO1:
	; reset TMR1 for timeout
	CLRF	TMR1H
	CLRF	TMR1L
	BCF	PIR1, TMR1IF
ACQ_DRO1_0:
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO1_timeout
	
	BTFSC	pin_DRO1_CLOCK	; wait for clock low
	GOTO	ACQ_DRO1_0
	CLRF	TMR0		; clear tmr0
	BCF	INTCON, TMR0IF	; clear flag
ACQ_DRO1_1:

	BTFSC	pin_DRO1_CLOCK	; check if clock high
	GOTO	ACQ_DRO1_0	; reacquire if under 1ms of idle
	
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO1_timeout
	
	BTFSS	INTCON, TMR0IF
	GOTO	ACQ_DRO1_1
	

	CLRF	data_0
	CLRF	data_1
	CLRF	data_2
	
	CLRF	loop_count
	
READ_DRO1_loop1:
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO1_timeout
	
	BTFSS	pin_DRO1_CLOCK		;wait for clock up
	GOTO	READ_DRO1_loop1


READ_DRO1_loop2:
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO1_timeout
	
	BTFSC	pin_DRO1_CLOCK		; wait for clock down
	GOTO	READ_DRO1_loop2
	
	BTFSC	pin_DRO1_DATA		; bits are inverted in input level transistor
	GOTO	READ_DRO1_skip
	
	BSetc	data_0, loop_count
READ_DRO1_skip:	
	INCF	loop_count, F
	CMP_lf	24, loop_count
	BR_NE	READ_DRO1_loop1
	
	MOVLW	'1'
	CALL	SEND_BYTE
	MOVLW	' '
	CALL	SEND_BYTE
	CALL	SEND_DATA
		
	; read and apply cfg for DRO1
	
	BTFSS	CFG, 5		; invert sign 10001100
	GOTO	DRO1_noInvert	
	
	MOVLW	0x10
	XORWF	data_2, F
	
	; suppress - sign for 000000
	MOVF	data_0, F
	BTFSS	STATUS, Z
	GOTO	DRO1_noInvert
	MOVF	data_1, F
	BTFSS	STATUS, Z
	GOTO	DRO1_noInvert
	MOVF	data_2, F
	BTFSS	STATUS, Z
	GOTO	DRO1_noInvert	
	BCF	data_2, 4
	
DRO1_noInvert:
	; save original sign for DRO1, and set actual for display
	BCF	data_status, 1
	BCF	data_status, 4
	BTFSS	data_2, 4
	GOTO	DRO1_noNeg
	BSF	data_status, 1
	BSF	data_status, 4
DRO1_noNeg:
	; clear sign from data packet
	BCF	data_2, 4

	; read config
	BTFSS	CFG, 1		; rad to dia 10001100
	GOTO	DRO1_noX2

 	BCF	STATUS, C
	RLF	data_0, F
	RLF	data_1, F
	RLF	data_2, F
	
DRO1_noX2:
	disp_select1; second display
	CALL	DISPLAYmm
	

	GOTO	LOOP



DRO0_timeout:
	BSF	PORTA, 4
	GOTO	ACQ_DRO1
DRO1_timeout:
	BSF	PORTA, 4	
	GOTO	LOOP

; routines	





	;PC0x0800SKIP
	
	
SEND_DATA:	
	MOVLW	HIGH (table_nibbleHex)
	MOVWF	PCLATH
	
	SWAPF	data_2, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	CALL	SEND_BYTE
	
	MOVF	data_2, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	CALL	SEND_BYTE
	
	SWAPF	data_1, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	CALL	SEND_BYTE
	
	MOVF	data_1, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	CALL	SEND_BYTE
	
	SWAPF	data_0, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	CALL	SEND_BYTE
	
	MOVF	data_0, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	CALL	SEND_BYTE

	CALL	SEND_CRLF
	RETURN
	
	
	
DISPLAYmm:
	BTFSC	data_status, 5 ; check if IN
	GOTO	DISPLAYin
	
	; clear digit 3 and 4 suppress bits	
	BCF	data_status, 7
	BCF	data_status, 6
	
	; binary to packed BCD	
	MOVLW	HIGH (BCD20)
	MOVWF	PCLATH
	CALL	BCD20

	; check if 2 last digits need to be suppressed (leading 0s)
	MOVF	data_BCD2, W
	ANDLW	0x0F
	BTFSS	STATUS, Z
	GOTO	DISPLAYmm_disp
	BSF	data_status, 7
	SWAPF	data_BCD1, W
	ANDLW	0x0F
	BTFSC	STATUS, Z
	BSF	data_status, 6
	
DISPLAYmm_disp:
	Peek_PORTB	
	CALL	TM1637_start
	
	MOVLW	_Data_Write
	MOVWF	disp_buffer	
	CALL	TM1637_data
	
	CALL	TM1637_stop
	
	CALL	TM1637_start
	
	MOVLW	_Address_C3H
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	MOVLW	HIGH (table_hexTo7seg)
	MOVWF	PCLATH
	
	MOVF	data_BCD0, W ; s0000.0x
	ANDLW	0x0F
	CALL	table_hexTo7seg
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	SWAPF	data_BCD0, W ; s0000.x0
	ANDLW	0x0F
	CALL	table_hexTo7seg
	MOVWF	disp_buffer
	CALL	TM1637_data	
	
	MOVF	data_BCD1, W ; s000x.00
	ANDLW	0x0F
	CALL	table_hexTo7seg
	MOVWF	disp_buffer
	BSF	disp_buffer, 7 ; dot	
	CALL	TM1637_data
	
	SWAPF	data_BCD1, W ; s00x0.00
	ANDLW	0x0F
	CALL	table_hexTo7seg
	BTFSC	data_status, 6
	CLRW
	MOVWF	disp_buffer
	CALL	TM1637_data
	

	MOVF	data_BCD2, W ; s00x0.00
	ANDLW	0x0F
	CALL	table_hexTo7seg
	BTFSC	data_status, 7
	CLRW
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	MOVLW	b'01000000';-
	MOVWF	disp_buffer
	BTFSS	data_status, 4
	CLRF	disp_buffer; empty

	CALL	TM1637_data	
	CALL	TM1637_stop
	
	CALL	TM1637_start	
	MOVLW	(_Display_ON | 4)
	MOVWF	disp_buffer
	CALL	TM1637_data	
	CALL	TM1637_stop
	
	RETURN
	

	
DISPLAYin:
	CALL	DIV_2p54
	
	; clear digit 4 suppress bit
	BCF	data_status, 7
	
	; binary to packed BCD	
	MOVLW	HIGH (BCD20)
	MOVWF	PCLATH
	CALL	BCD20		
	
	; check if last digit need to be suppressed (leading 0)
	MOVF	data_BCD2, W
	ANDLW	0x0F
	BTFSS	STATUS, Z
	GOTO	DISPLAYin_disp
	BSF	data_status, 7
	
DISPLAYin_disp:
	Peek_PORTB	
	CALL	TM1637_start
	
	MOVLW	_Data_Write
	MOVWF	disp_buffer	
	CALL	TM1637_data
	
	CALL	TM1637_stop
	
	CALL	TM1637_start
	
	MOVLW	_Address_C3H
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	MOVLW	HIGH (table_hexTo7seg)
	MOVWF	PCLATH
	
	MOVF	data_BCD0, W ; s00.00x
	ANDLW	0x0F
	CALL	table_hexTo7seg
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	SWAPF	data_BCD0, W ; s00.0x0
	ANDLW	0x0F
	CALL	table_hexTo7seg
	MOVWF	disp_buffer
	CALL	TM1637_data	
	
	MOVF	data_BCD1, W ; s00.x00
	ANDLW	0x0F
	CALL	table_hexTo7seg
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	SWAPF	data_BCD1, W ; s0x.000
	ANDLW	0x0F
	CALL	table_hexTo7seg
	MOVWF	disp_buffer
	BSF	disp_buffer, 7 ; dot	
	CALL	TM1637_data
	

	MOVF	data_BCD2, W ; sx0.000
	ANDLW	0x0F
	CALL	table_hexTo7seg
	BTFSC	data_status, 7
	CLRW
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	MOVLW	b'01000000';-
	MOVWF	disp_buffer
	BTFSS	data_status, 4
	CLRF	disp_buffer; empty

	CALL	TM1637_data	
	CALL	TM1637_stop
	
	CALL	TM1637_start	
	MOVLW	(_Display_ON | 4)
	MOVWF	disp_buffer
	CALL	TM1637_data	
	CALL	TM1637_stop
	
	RETURN

; UART routines
SEND_BYTE:	; send byte to UART, blocking
	BTFSS	PIR1, TXIF
	GOTO	SEND_BYTE
	MOVWF	TXREG
	RETURN

SEND_CRLF:
	BTFSS	PIR1, TXIF
	GOTO	SEND_CRLF
	MOVLW	0x0D
	MOVWF	TXREG
SEND_CRLF_0:
	BTFSS	PIR1, TXIF
	GOTO	SEND_CRLF_0
	MOVLW	0x0A
	MOVWF	TXREG
	RETURN

;#############################################################################
; TM1637 routines
;#############################################################################

TM1637_start:
	Pin_Data_DOWN
	Update_PORTB
	RETURN
	
;loop version
TM1637_data:	; data is in file "disp_buffer";
	MOVLW	8
	MOVWF	loop_count
	
TM1637_dataLoop:
	Pin_Clk_DOWN
	Update_PORTB

	BTFSC	disp_buffer, 0
	GOTO	TM1637_dataUP
	
	Pin_Data_DOWN
	
	GOTO	TM1637_dataDone
TM1637_dataUP:
	Pin_Data_UP
	
TM1637_dataDone:
	Pin_Clk_UP
	Update_PORTB
	
	RRF	disp_buffer, F
	
	DECFSZ	loop_count, F
	GOTO	TM1637_dataLoop

	;ACK
	Pin_Clk_DOWN
	Pin_Data_UP
	Update_PORTB	

	Pin_Clk_UP
	Update_PORTB

	Pin_Clk_DOWN
	Pin_Data_DOWN
	Update_PORTB
	RETURN

TM1637_stop:
	Pin_Data_DOWN
	Update_PORTB
	Pin_Clk_UP
	Update_PORTB
	Pin_Data_UP
	Update_PORTB
	CALL 	WAIT_50us
	RETURN


;#############################################################################
;	MATH!
;#############################################################################

;20 bit to Packed BCD

BCD20:
	BCF	STATUS, IRP
	CLRF	data_BCD0
	CLRF	data_BCD1
	CLRF	data_BCD2
	CLRF	data_BCD3
	MOVLW	23; 0x17		;Rotate and Increment 23 time
	MOVWF	loop_count

BCD20_rot:
 	BCF	STATUS, C
	RLF	data_0, F
	RLF	data_1, F
	RLF	data_2, F
	RLF	data_BCD0, F
	RLF	data_BCD1, F
	RLF	data_BCD2, F
	RLF	data_BCD3, F

	MOVLW	data_BCD0
	MOVWF	FSR
	MOVLW	0x04
	MOVWF	loop_count_2
BCD20_Hnibble:
	SWAPF	INDF, W
	ANDLW	0x0F
	SUBLW	0x04
	BTFSC	STATUS, C
	GOTO	BCD20_Lnibble
	MOVLW	0x30
	ADDWF	INDF, F
BCD20_Lnibble:
	MOVLW	0x0F
	ANDWF	INDF, W
	SUBLW	0x04
	BTFSC	STATUS, C
	GOTO	BCD20_end
	MOVLW	0x03
	ADDWF	INDF, F
BCD20_end:
	INCF	FSR, F
	DECFSZ	loop_count_2, F
	GOTO	BCD20_Hnibble

	DECFSZ	loop_count, F
	GOTO	BCD20_rot

 	BCF	STATUS, C		;24Th Time no C5A3
	RLF	data_0, F
	RLF	data_1, F
	RLF	data_2, F
	RLF	data_BCD0, F
	RLF	data_BCD1, F
	RLF	data_BCD2, F
	RLF	data_BCD3, F
	
	RETURN


;#############################################################################
;	div / 2.54
;#############################################################################
DIV_2p54:
	; result is data * 100 / 254
	; data = data * 100
	; accum = ROUND(data / 256)
	; accum = accum + ROUND(accum / 32k)
	; accum = accum + FLOOR(accum / 4m)
	; good up to 24 inches
	
	BCF	STATUS, C
	RLFc	data_0 ;x2
	RLFc	data_0 ;x4
	MOVc	data_0, accum_0 ; accum is data * 4
			
	BCF	STATUS, C
	RLFc	data_0 ;x8
	RLFc	data_0 ;x16
	RLFc	data_0 ;x32		
	ADDc	accum_0, data_0 ; accum is data * 4 + data * 32
	
	BCF	STATUS, C
	RLFc	data_0 ;x64
	ADDc	data_0, accum_0 ; data is data * 4 + data * 32 + data * 64 = (100 * data)

;         no shift,	1byte,	2byte
; no bit shift  /1	/256	/64k	0
; after /2      /2	/512	/128k	1
; after /4      /4	/1024	/256k	2
; after /8      /8	/2k	/512k	3
; after /16	 /16	/4k	/1m	4
; after /32	 /32	/8k	/2m	5
; after /64	 /64	/16k	/4m*	6
; after /128	/128	/32k*	/8m	7

; after /256 	/256*	/64k	/16m	byte shift

	MOVF	data_0, W
	MOVWF	data_f		; keep fraction
	MOVF	data_1, W
	MOVWF	data_0
	MOVF	data_2, W
	MOVWF	data_1		 
	CLRF	data_2		 ; data = data / 256
	
	BTFSS	data_f, 7	; check if end in 0.5
	GOTO	t6_0
	INCFc	data_0		; round up	
t6_0:
	MOVc	data_0, accum_0 ; accum = ROUND(data / 256)
	
	; 64 aa bb /256
	; 00 64 aa /256 (/64k)
	; 00 00 64 aa *2
	; 00 00 C8 bb (/32k)

	MOVF	data_0, W
	MOVWF	data_f		; keep fraction
	MOVF	data_1, W
	MOVWF	data_0
	MOVF	data_2, W
	MOVWF	data_1		 
	CLRF	data_2		 ; data = data / 256 (total of 64k)
	
	BCF	STATUS, C
	RLFi	data_f		; 32 bit integer x2, data, is now data / 256 / 256 x2 or /32k
	
	BTFSS	data_f, 7	; check if end in 0.5
	GOTO	t6_1
	INCFc	data_0		; round up	
t6_1:
	ADDc	accum_0, data_0 ; accum = ROUND(data / 256) + ROUND(data / 32k)
	
	; 64 aa bb /256
	; 00 64 aa /256 (/64k)
	; 00 00 64 aa *2
	; 00 00 C8 bb (/32k)
	; 00 00 00 C8 bb /256 (8m)
	; 00 00 01 90 00 *2 (4m)

	MOVF	data_0, W
	MOVWF	data_f		; keep fraction
	MOVF	data_1, W
	MOVWF	data_0
	MOVF	data_2, W
	MOVWF	data_1		 
	CLRF	data_2		 ; data = data/32 / 256 (total of 8m)
	
	BCF	STATUS, C
	RLFi	data_f		; 32 bit integer x2, data, is now data / 4m
	
	ADDc	data_0, accum_0 ; data = ROUND(data / 256) + ROUND(data / 32k) + FLOOR(data / 4m)
	
	RETURN

;#############################################################################
;	Tables
;#############################################################################

	PC0x0100SKIP; align to next 256 byte boundary in program memory
	
; nibble to char
table_nibbleHex:
	ADDWF	PCL, F
	dt	"0123456789ABCDEF"

; byte to 7+1 segments
table_hexTo7seg:
	ADDWF	PCL, F
	RETLW	b'00111111';0
	RETLW	b'00000110';1
	RETLW	b'01011011';2
 	RETLW	b'01001111';3
	RETLW	b'01100110';4
 	RETLW	b'01101101';5
	RETLW	b'01111101';6
 	RETLW	b'00000111';7
 	RETLW	b'01111111';8
 	RETLW	b'01101111';9
 	RETLW	b'01110111';A
 	RETLW	b'01111100';b
 	RETLW	b'00111001';C
 	RETLW	b'01011110';d
 	RETLW	b'01111001';E
 	RETLW	b'01110001';F
	RETLW	b'10000000';.
	RETLW	b'01000000';-
	
;    aaa
;  f     b
;  f     b
;  f     b
;    ggg
;  e     c
;  e     c
;  e     c
;    ddd
;	  p

; bit 76543210
; seg pgfedcba 

	
;#############################################################################
;	Delay routines	for 8MHz
;	 at 8MHz intrc, 2Mips, 0.5us per instruction cycle
;#############################################################################
; 2 000 000 cycles
 
WAIT_1s:				; (2) call
	MOVLW	10			; (1) 10x 200 000
	MOVWF	WAIT_loopCounter1	; (1)
; 4 overhead
WAIT_1s_loop1:
	MOVLW	200			; (1) for 100 ms
	MOVWF	WAIT_loopCounter2	; (1)
; loop 1 overhead 5 * 200
WAIT_1s_loop2:			; 0.5ms / loop1
	MOVLW	250 - 2			; (1) 250 loops of 4 cycles (minus 2 loop for setup and next loop)
	MOVWF	WAIT_loopCounter3	; (1)
	GOTO 	$ + 1			; (2)	
; loop 2 overhead 7 * 248
WAIT_1s_loop3:			; 4 cycles per loop (2us / loop2)
	NOP				; (1)
	DECFSZ	WAIT_loopCounter3, F	; (1)
	GOTO	WAIT_1s_loop3		; (2)
	
	GOTO 	$ + 1			; (2)
	
	DECFSZ	WAIT_loopCounter2, F	; (1)
	GOTO	WAIT_1s_loop2		; (2)

	DECFSZ	WAIT_loopCounter1, F	; (1)
	GOTO	WAIT_1s_loop1		; (2)
	RETURN				; (2)
; 2 return


WAIT_50ms:;100006 cycles or 50.003 ms; (2) call
	MOVLW	100			; (1)
	MOVWF	WAIT_loopCounter1	; (1)
WAIT_50ms_loop1:			; 0.5ms / loop1
	MOVLW	199			; (1) 250 loops of 4 cycles (minus 2 loop for setup and next loop)
	MOVWF	WAIT_loopCounter2	; (1)
WAIT_50ms_loop2:			;  5 cycles per loop (2us / loop2)
	GOTO 	$ + 1			; (2)	
	DECFSZ	WAIT_loopCounter2, F	; (1)
	GOTO	WAIT_50ms_loop2	; (2)
	DECFSZ	WAIT_loopCounter1, F	; (1)
	GOTO	WAIT_50ms_loop1	; (2)
	RETURN				; (2)

WAIT_50us:				; (2) call is 2 cycle
	MOVLW	23			; (1) 100 instruction for 50 us, 1 == 10 cycles = 5us, 2 is 14, 3 is 18, 4 is 22
	MOVWF	WAIT_loopCounter1	; (1)
WAIT_50us_loop:
	NOP				; (1)
	DECFSZ	WAIT_loopCounter1, F	; (1)
	GOTO	WAIT_50us_loop		; (2)
	GOTO	$ + 1			; (2)
	RETURN				; (2)
	
WAIT_5us:				; (2) call is 2 cycle
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	RETURN				; (2) return is 2 cycle

;#############################################################################
;	EEPROM default for testing
;#############################################################################
	
	ORG	0x2100 ; the address of EEPROM is 0x2100 
	DE	b'00110001'
; EEPROM data byte at 0x00 is config
; bit 0-3 x2 axis 0-3 (for radius to diameter direct reading)
; bit 4-7 is reverse axis direction
;#############################################################################
;	End Declaration
;#############################################################################

	END

	
	
	
	
	
	
	
	
