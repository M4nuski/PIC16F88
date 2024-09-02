;#############################################################################
;
;	Lathe DRO control for chineese DRO scale
;	Read raidus and length
;	Display on 2 TM1637 6-digits 7-segments
;	Input with 4x4 keypad trough 74LS164 as 1 bit scanner 
;
;#############################################################################
;
;	Version 1c
;	2 DRO scale sampling, display on 2 TM1637
;	SEG brightness in EEPROM config
;	Convert DRO from radius to diameter
;	Convert from MM to INCHES (0.001)
;	Scale reverse and rad/dia in EEPROM config
;	Output on UART at 9600 bauds
;	Keypad entry
;
;	TODO : put sign bit back in data_0 or dro0_0 etc or entry offset_0 
;	suppress only when all 0s in display
;	siwtch polarity only when reading raw data from DRO
; baseline Program Memory Words Used:  1472
;
;;#############################################################################
;
;	MM to IN
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
;          0   -   OK
;
;      7   8   9   X
;      4   5   6   Y
;      1   2   3   Z
;     1/2  0   -   OK
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
;
; 4x4 1 bit keypad scanner per
; https://hackaday.com/2015/04/15/simple-keypad-scanning-with-spi-and-some-hardware/
;
; from connector at the left
; VCC
; CLK
; DATA
; GND
; INPUT/SENS
;
;	0 [1]	1 [2]	2 [3]	3 [A]
;	4 [4]	5 [5]	6 [6]	7 [B]
;	8 [7]	9 [8]	10[9]	11[C]
;	12[*]	13[0]	14[#]	15[D]
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
; pin  3 IOA PORTA4	O Keypad Clock
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O DISP Clock 
; pin  7 IO_ PORTB1	O DISP0 Data
; pin  8 IOR PORTB2	I UART RX
; pin  9 IO_ PORTB3	O DISP1 Data

; pin 10 IO_ PORTB4	I UNIT SWITCH
; pin 11 IOT PORTB5	O UART TX
; pin 12 IOA PORTB6	I ICSP PGC
; pin 13 IOA PORTB7	I ICSP PGD
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O Keypad Output
; pin 16 I_X PORTA7	I Keypad Input	
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
#DEFINE pin_KEYPAD_CLOCK	PORTA, 4
;#DEFINE MCLR			PORTA, 5
#DEFINE pin_KEYPAD_OUTPUT	PORTA, 6
#DEFINE pin_KEYPAD_INPUT	PORTA, 7

#DEFINE pin_Disp_CLOCK	PORTB, 0
#DEFINE pin_Disp0_DATA	PORTB, 1
;#DEFINE UART RX		PORTB, 2
#DEFINE pin_Disp1_DATA	PORTB, 3

#DEFINE pin_SWITCH		PORTB, 4
#DEFINE pin_UART_TX		PORTB, 5
#DEFINE pin_debug2		PORTB, 6 ; PGC
#DEFINE pin_debug1		PORTB, 7 ; PGD

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


WAIT_loopCounter1	EQU	0x20
WAIT_loopCounter2	EQU	0x21
loop_count		EQU	0x22
loop_count_2		EQU	0x23

; raw DRO data
dro0_0			EQU	0x24
dro0_1			EQU	0x25
dro0_2			EQU	0x26

dro1_0			EQU	0x27
dro1_1			EQU	0x28
dro1_2			EQU	0x29

;dro2_0			EQU	0x2A
;dro2_1			EQU	0x2B
;dro2_2			EQU	0x2C

keypad_key		EQU	0x30
keypad_last		EQU	0x31
bit_keyUp		EQU	6
bit_keyRepeat		EQU	7
keymap_entryMode	EQU	0x32
bit_keyEntry0		EQU	0	; entering dro0 actual
bit_keyEntry1		EQU	1	; entering dro1 actual
;bit_keyEntry2		EQU	2	; entering dro2 actual
bit_keyEntry		EQU	3	; entering actual
bit_keySign		EQU	6	; entering sign
mask_keySign		EQU	0x40
bit_keySwitchLast	EQU	7	; unit switch last state

; current entry
dro_offset0		EQU	0x34
dro_offset1		EQU	0x35
dro_offset2		EQU	0x36

dro0_offset0		EQU	0x37
dro0_offset1		EQU	0x38
dro0_offset2		EQU	0x39

dro1_offset0		EQU	0x3A
dro1_offset1		EQU	0x3B
dro1_offset2		EQU	0x3C

;dro2_offset0		EQU	0x3D
;dro2_offset1		EQU	0x3E
;dro2_offset2		EQU	0x3F

; current data
data_f			EQU	0x40
data_0			EQU	0x41
data_1			EQU	0x42
data_2			EQU	0x43
bit_data_2Sign		EQU	4
mask_data_2Sign	EQU	0x10

accum_0			EQU	0x44
accum_1			EQU	0x45
accum_2			EQU	0x46

data_status		EQU	0x48
bit_statusDRO0Sign	EQU	0
bit_statusDRO1Sign	EQU	1
;bit_statusDRO2Sign	EQU	2
bit_statusEntryMode	EQU	3
bit_statusCurrentSign	EQU	4
mask_statusCurrentSign EQU	0x10 
bit_statusCurrentUnit	EQU	5 ; 0:mm, 1:in
mask_statusCurrentUnit EQU	0x20 
bit_statusSuppressD3	EQU	6
bit_statusSuppressD4	EQU	7

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

CFG			EQU	0x60
bit_CFGdia0		EQU	0
bit_CFGdia1		EQU	1
bit_CFGdia2		EQU	2
;bit_CFG		EQU	3
bit_CFGreverse0	EQU	4
bit_CFGreverse1	EQU	5
bit_CFGreverse2	EQU	6
;bit_CFG		EQU	7
CFG_1			EQU	0x61	; display brightness


; TM1637 line output masks:
#DEFINE ClockClear	b'11111110'
#DEFINE ClockSet	b'00000001'

#DEFINE Data0Clear	b'11111101'
#DEFINE Data0Set	b'00000010'

#DEFINE Data1Clear	b'11110111'
#DEFINE Data1Set	b'00001000'

;#DEFINE Data2Clear	b'11110111'
;#DEFINE Data2Set	b'00001000'

; TM1637 commands:
#DEFINE _Data_Write		b'01000000'
#DEFINE _Address_C3H		b'11000011'
#DEFINE _Display_ON		b'10001000'
#DEFINE _Display_OFF		b'10000000'

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
	
RNLc	MACRO	file
;  HN2 LN2 HN1 LN1 HN0 LN0
	SWAPF	file + 2, F
	SWAPF	file + 1, F
	SWAPF	file + 0, F	
;  LN2 HN2 LN1 HN1 LN0 HN0
	MOVLW	0xF0
	ANDWF	file + 2, F
;  LN2 000 LN1 HN1 LN0 HN0
	MOVLW	0x0F
	ANDWF	file + 1, W
	IORWF	file + 2, F
;  LN2 HN1 LN1 HN1 LN0 HN0
	MOVLW	0xF0
	ANDWF	file + 1, F
;  LN2 HN1 LN1 000 LN0 HN0
	MOVLW	0x0F
	ANDWF	file + 0, W
	IORWF	file + 1, F
;  LN2 HN1 LN1 HN0 LN0 HN0
	MOVLW	0xF0
	ANDWF	file + 0, F
;  LN2 HN1 LN1 HN0 LN0 000
	ENDM


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
	
	BSF	pin_KEYPAD_INPUT ; input
	BSF	pin_SWITCH	  ; input

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
	MOVLW	'c'
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
	
	MOVLW	_Display_ON | 7

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
	
	MOVLW	_Display_ON | 7
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
	
	BANKSEL	EEADR	; Select Bank of EEADR
	MOVLW	0x01	; Address const
	MOVWF	EEADR 	; Data Memory Address to read
	BANKSEL	EECON1 ; Select Bank of EECON1
	BCF	EECON1, EEPGD; Point to Data memory

	BSF 	EECON1, RD ; EE Read
	BANKSEL	EEDATA ; Select Bank of EEDATA
	MOVF	EEDATA, W ; W = EEDATA
	BANKSEL	CFG_1
	MOVWF	CFG_1

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
	
	
	CLRF	data_status
	CLRF	keymap_entryMode
	
	; setup serial to parallel keypad interface
	
	CLRF	keypad_key
	CLRF	keypad_last
	
	MOVLW	0x08
	MOVWF	loop_count
main_keypad_reset:
	BCF	pin_keypad_CLOCK
	CALL	WAIT_50us
	BSF	pin_keypad_CLOCK
	CALL	WAIT_50us
	DECFSZ	loop_count, F
	GOTO	main_keypad_reset	
	
	
	MOVLW	20
	MOVWF	loop_count
main_wait:
	CALL	WAIT_50ms
	DECFSZ	loop_count, F
	GOTO	main_wait



LOOP:
	
ACQ_DRO0:
	MOVLW	0x80
	XORWF	PORTB, F

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
	
	BCF	pin_debug1
	
	; read and apply cfg for DRO0
	
	BTFSS	CFG, bit_CFGreverse0	; invert sign 10001100
	GOTO	DRO0_noInvert	
	
	MOVLW	mask_data_2Sign
	XORWF	data_2, F

	
DRO0_noInvert:	
	; save original sign for DRO0, and set actual for display
	BCF	data_status, bit_statusDRO0Sign
	BCF	data_status, bit_statusCurrentSign
	BTFSS	data_2, bit_data_2Sign
	GOTO	DRO0_notNeg
	BSF	data_status, bit_statusDRO0Sign
	BSF	data_status, bit_statusCurrentSign
DRO0_notNeg:
	; clear sign from data packet
	BCF	data_2, bit_data_2Sign

	; read config
	BTFSS	CFG, bit_CFGdia0 ; rad to dia 10001100
	GOTO	DRO0_noX2

 	BCF	STATUS, C
	RLF	data_0, F
	RLF	data_1, F
	RLF	data_2, F
	
DRO0_noX2:
	disp_select0; first display	
	
	BTFSS	keymap_entryMode, bit_keyEntry1
	GOTO	DRO0_disp1

	CALL	DISPLAYCLEAR	
	CALL	PROCESS_KEYS
	GOTO	ACQ_DRO1
		
DRO0_disp1:
	BTFSC	keymap_entryMode, bit_keyEntry0 ; change the sign for current entry sign
	GOTO	DRO0_disp2
	BCF	data_status, bit_statusCurrentSign
	BTFSC	keymap_entryMode, bit_keySign
	BSF	data_status, bit_statusCurrentSign
	
DRO0_disp2:
	CALL	DISPLAYmm	
	CALL	PROCESS_KEYS
	

	
	
	
	

ACQ_DRO1:
	MOVLW	0x80
	XORWF	PORTB, F
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
	
		
	; read and apply cfg for DRO1
	
	BTFSS	CFG, bit_CFGreverse1	; invert sign 10001100
	GOTO	DRO1_noInvert	
	
	MOVLW	mask_data_2Sign
	XORWF	data_2, F
	
	; suppress - sign for 000000
	; MOVF	data_0, F
	; BTFSS	STATUS, Z
	; GOTO	DRO1_noInvert
	; MOVF	data_1, F
	; BTFSS	STATUS, Z
	; GOTO	DRO1_noInvert
	; MOVF	data_2, F
	; BTFSS	STATUS, Z
	; GOTO	DRO1_noInvert	
	; BCF	data_2, bit_data_2Sign
	
DRO1_noInvert:
	; save original sign for DRO1, and set actual for display
	BCF	data_status, bit_statusDRO1Sign
	BCF	data_status, bit_statusCurrentSign
	BTFSS	data_2, bit_data_2Sign
	GOTO	DRO1_noNeg
	BSF	data_status, bit_statusDRO1Sign
	BSF	data_status, bit_statusCurrentSign
DRO1_noNeg:
	; clear sign from data packet
	BCF	data_2, bit_data_2Sign

	; read config
	BTFSS	CFG, bit_CFGdia1 ; rad to dia 10001100
	GOTO	DRO1_noX2

 	BCF	STATUS, C
	RLF	data_0, F
	RLF	data_1, F
	RLF	data_2, F
	
DRO1_noX2:
	disp_select1; second display
	
	BTFSS	keymap_entryMode, bit_keyEntry0
	GOTO	DRO1_disp1

	CALL	DISPLAYCLEAR	
	CALL	PROCESS_KEYS
	GOTO	LOOP
		
DRO1_disp1:
	BTFSC	keymap_entryMode, bit_keyEntry1 ; change the sign for current entry sign
	GOTO	DRO1_disp2
	BCF	data_status, bit_statusCurrentSign
	BTFSC	keymap_entryMode, bit_keySign
	BSF	data_status, bit_statusCurrentSign
	
DRO1_disp2:
	CALL	DISPLAYmm	
	CALL	PROCESS_KEYS

	GOTO	LOOP



DRO0_timeout:
	BSF	pin_debug2
	GOTO	ACQ_DRO1
DRO1_timeout:
	BSF	pin_debug2	
	GOTO	LOOP


;#############################################################################
;	SUBROUTINES
;#############################################################################
	
;#############################################################################
;	Data conversion and UART TX
;#############################################################################

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
	
;#############################################################################
;	DISPLAY 7 segs
;#############################################################################
	
DISPLAYmm:
	BTFSC	data_status, bit_statusCurrentUnit ; check if IN
	GOTO	DISPLAYin
	
	; clear digit 3 and 4 suppress bits	
	BCF	data_status, bit_statusSuppressD4
	BCF	data_status, bit_statusSuppressD3
	
	BTFSS	keymap_entryMode, bit_keyEntry
	GOTO	DISPLAYmm_bin2BCD
	
	MOVc	dro_offset0, data_BCD0
	GOTO	DISPLAYmm_checkSupp
	
DISPLAYmm_bin2BCD:	
	; binary to packed BCD	
	MOVLW	HIGH (BCD20)
	MOVWF	PCLATH
	CALL	BCD20
	
	


DISPLAYmm_checkSupp:
	; check if 2 last digits need to be suppressed (leading 0s)
	MOVF	data_BCD2, W
	ANDLW	0x0F
	BTFSS	STATUS, Z
	GOTO	DISPLAYmm_check0
	BSF	data_status, bit_statusSuppressD4
	SWAPF	data_BCD1, W
	ANDLW	0x0F
	BTFSC	STATUS, Z
	BSF	data_status, bit_statusSuppressD3
	
DISPLAYmm_check0:
	; check if minus sign need to be suppressed
	MOVF	data_BCD0, F
	BTFSS	STATUS, Z
	GOTO	DISPLAYmm_disp
	MOVF	data_BCD1, F
	BTFSS	STATUS, Z
	GOTO	DISPLAYmm_disp
	MOVF	data_BCD2, F
	BTFSS	STATUS, Z
	GOTO	DISPLAYmm_disp	
	BCF	data_status, bit_statusCurrentSign
	 
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
	BTFSC	data_status, bit_statusSuppressD3
	CLRW
	MOVWF	disp_buffer
	CALL	TM1637_data
	

	MOVF	data_BCD2, W ; s00x0.00
	ANDLW	0x0F
	CALL	table_hexTo7seg
	BTFSC	data_status, bit_statusSuppressD4
	CLRW
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	MOVLW	b'01000000';-
	MOVWF	disp_buffer
	BTFSS	data_status, bit_statusCurrentSign
	CLRF	disp_buffer; empty
	CALL	TM1637_data	
	
	CALL	TM1637_stop
	
	CALL	TM1637_start	
	MOVLW	_Display_ON
	IORWF	CFG_1, W
	MOVWF	disp_buffer
	CALL	TM1637_data	
	CALL	TM1637_stop
	
	RETURN
	

	
DISPLAYin:
	CALL	DIV_2p54
	
	; clear digit 4 suppress bit
	BCF	data_status, bit_statusSuppressD4
	
	BTFSS	keymap_entryMode, bit_keyEntry
	GOTO	DISPLAYin_bin2BCD
	
	MOVc	dro_offset0, data_BCD0
	GOTO	DISPLAYin_checkSupp
	
DISPLAYin_bin2BCD:	

	; binary to packed BCD	
	MOVLW	HIGH (BCD20)
	MOVWF	PCLATH
	CALL	BCD20
	
DISPLAYin_checkSupp:
	; check if last digit need to be suppressed (leading 0)
	MOVF	data_BCD2, W
	ANDLW	0x0F
	BTFSS	STATUS, Z
	GOTO	DISPLAYin_check0
	BSF	data_status, bit_statusSuppressD4
	
DISPLAYin_check0:
	; check if minus sign need to be suppressed
	MOVF	data_BCD0, F
	BTFSS	STATUS, Z
	GOTO	DISPLAYin_disp
	MOVF	data_BCD1, F
	BTFSS	STATUS, Z
	GOTO	DISPLAYin_disp
	MOVF	data_BCD2, W
	ANDLW	0x0F
	BTFSS	STATUS, Z
	GOTO	DISPLAYin_disp	
	BCF	data_status, bit_statusCurrentSign
	
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
	BTFSC	data_status, bit_statusSuppressD4
	CLRW
	MOVWF	disp_buffer
	CALL	TM1637_data
	
	MOVLW	b'01000000';-
	MOVWF	disp_buffer
	BTFSS	data_status, bit_statusCurrentSign
	CLRF	disp_buffer; empty
	CALL	TM1637_data	
	
	CALL	TM1637_stop
	
	CALL	TM1637_start	
	MOVLW	_Display_ON
	IORWF	CFG_1, W
	MOVWF	disp_buffer
	CALL	TM1637_data	
	CALL	TM1637_stop
	
	RETURN

DISPLAYCLEAR:
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

	MOVLW	6
	MOVWF	loop_count_2
DISPLAYCLEAR_loop:
	CLRF	disp_buffer
	CALL	TM1637_data
	DECFSZ	loop_count_2, F
	GOTO	DISPLAYCLEAR_loop
	
	CALL	TM1637_start
	MOVLW	_Display_OFF
	CALL	TM1637_data
	CALL	TM1637_stop
	
	RETURN




;#############################################################################
;	UART
;#############################################################################

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
;	KEYPAD
;#############################################################################

PROCESS_KEYS:

	BTFSC	keymap_entryMode, bit_keyEntry	; skip unit toggle in entry mode
	GOTO	PROCESS_KEYS_s1
	
	BTFSC	pin_SWITCH		; clear when pressed
	GOTO	PROCESS_KEYS_sdown
	; switch is up	
	GOTO	PROCESS_KEYS_s0
	
PROCESS_KEYS_sdown:

	; check if already down
	BTFSC	keymap_entryMode, bit_keySwitchLast
	GOTO	PROCESS_KEYS_s1	

	MOVLW	mask_statusCurrentUnit
	XORWF	data_status, F	; toggle current unit bit
	BSF	keymap_entryMode, bit_keySwitchLast
	GOTO	PROCESS_KEYS_s1
	
PROCESS_KEYS_s0:
	BCF	keymap_entryMode, bit_keySwitchLast
	
PROCESS_KEYS_s1:
	; scan keypad
	BSF	pin_debug2	
	
	CLRF	data_0
	
	BSF	pin_KEYPAD_OUTPUT	; read bit to 1
	CALL	WAIT_50us
	BCF	pin_KEYPAD_CLOCK
	CALL	WAIT_50us
	BSF	pin_KEYPAD_CLOCK
	CALL	WAIT_50us
	
	BTFSC	pin_KEYPAD_INPUT
	BSF	data_0, 0	
	BCF	pin_KEYPAD_OUTPUT	; read bit to 0	
	
	MOVLW	7			; loop for the 7 remaining bits
	MOVWF	loop_count
PROCESS_KEYS_scanloop:
	BCF	STATUS, C
	RLF	data_0, F
	
	CALL	WAIT_50us
	BCF	pin_KEYPAD_CLOCK
	CALL	WAIT_50us
	BSF	pin_KEYPAD_CLOCK
	CALL	WAIT_50us
	
	BTFSC	pin_KEYPAD_INPUT
	BSF	data_0, 0
		
	DECFSZ	loop_count, F
	GOTO	PROCESS_KEYS_scanloop
	
	;MOVF	data_0, W
	;CALL	SEND_BYTE
	;
	;GOTO PROCESS_KEYS_decode
	; check data valid
	BCF	pin_debug2
	
	CLRF	data_2		; clear 2 for count
	MOVF	data_0, W	; copy data to 1, will be destroyed when counting
	MOVWF	data_1
	
	MOVLW	8
	MOVWF	loop_count
PROCESS_KEYS_bitloop:
	BCF	STATUS, C
	RRF	data_1, F
	BTFSC	STATUS, C
	INCF	data_2, F
	DECFSZ	loop_count, F
	GOTO	PROCESS_KEYS_bitloop
	
	MOVF	data_2, W
	SUBLW	2		; no valid key if bit count !=2
	BR_EQ	PROCESS_KEYS_decode
	BSF	keypad_key, bit_keyUp ; mark as different
	GOTO	PROCESS_KEYS_validate
	
	
PROCESS_KEYS_decode:
	BCF	pin_debug2
		
	; data_0 now has valid keypad scan
	
	; 0001 0001 0
	; 0001 0010 1
	; 0001 0100 2
	; 0001 1000 3
	
	; 0010 0001 4
	; 0010 0010 5 
	; 0010 0100 6
	; 0010 1000 7
	CLRW
	; 0 of bit 0 is implied
	BTFSC	data_0, 1
	MOVLW	1
	BTFSC	data_0, 2
	MOVLW	2
	BTFSC	data_0, 3
	MOVLW	3

	MOVWF	keypad_key
	
	CLRW
	BTFSC	data_0, 5
	MOVLW	4
	BTFSC	data_0, 6
	MOVLW	8
	BTFSC	data_0, 7
	MOVLW	12
	
	ADDWF	keypad_key, F ; key now has the key number	
	
PROCESS_KEYS_validate:
	MOVF	keypad_key, W
	XORWF	keypad_last, W
	SK_NE
	BSF	keypad_key, bit_keyRepeat ;mark bit if repeat

	; for debug
	MOVF	keypad_key, W
	CALL	SEND_BYTE
	
	MOVF	keypad_key, W
	MOVWF	keypad_last
	BCF	keypad_last, bit_keyRepeat
	
;#############################################################################
;	Process Commands
;#############################################################################
	MOVLW	15
	SUBWF	keypad_key, W
	BR_GT	PROCESS_KEYS_END
	

	
	PC0x0100SKIP
	MOVLW	HIGH (PROCESS_KEYS_00)
	MOVWF	PCLATH
	
	MOVF	keypad_key, W
	ADDWF	PCL, F
	GOTO	PROCESS_KEYS_00
	GOTO	PROCESS_KEYS_01
	GOTO	PROCESS_KEYS_02
	GOTO	PROCESS_KEYS_03
	
	GOTO	PROCESS_KEYS_04
	GOTO	PROCESS_KEYS_05
	GOTO	PROCESS_KEYS_06
	GOTO	PROCESS_KEYS_07
	
	GOTO	PROCESS_KEYS_08
	GOTO	PROCESS_KEYS_09
	GOTO	PROCESS_KEYS_10
	GOTO	PROCESS_KEYS_11
	
	GOTO	PROCESS_KEYS_12
	GOTO	PROCESS_KEYS_13
	GOTO	PROCESS_KEYS_14
	GOTO	PROCESS_KEYS_15

	
PROCESS_KEYS_00:
	; key 00[7]
	BTFSS	keymap_entryMode, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset0
	MOVLW	7
	IORWF	dro_offset0, F

	GOTO	PROCESS_KEYS_END
PROCESS_KEYS_01:
	; key 01[8]
	BTFSS	keymap_entryMode, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset0
	MOVLW	8
	IORWF	dro_offset0, F

	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_02:
	; key 00[9]
	BTFSS	keymap_entryMode, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset0
	MOVLW	9
	IORWF	dro_offset0, F

	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_03:
	; key 03[A] for DRO0 select

	BTFSC	keymap_entryMode, bit_keyEntry0
	GOTO	PROCESS_KEYS_03_reset
	BTFSC	keymap_entryMode, bit_keyEntry1
	GOTO	PROCESS_KEYS_03_reset
	
	BSF	keymap_entryMode, bit_keyEntry0
	BCF	keymap_entryMode, bit_keySign

	CLRF	dro_offset0
	CLRF	dro_offset1
	CLRF	dro_offset2
	
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_03_reset:
	BCF	keymap_entryMode, bit_keyEntry0
	BCF	keymap_entryMode, bit_keyEntry1
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_04:
	; key 04[4]
	BTFSS	keymap_entryMode, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset0
	MOVLW	4
	IORWF	dro_offset0, F

	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_05:
	; key 05[5]
	BTFSS	keymap_entryMode, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset0
	MOVLW	5
	IORWF	dro_offset0, F

	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_06:
	; key 06[6]

	BTFSS	keymap_entryMode, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset0
	MOVLW	6
	IORWF	dro_offset0, F

	GOTO	PROCESS_KEYS_END

PROCESS_KEYS_07:	
	; key 07[B] for DRO1 select
	
	BTFSC	keymap_entryMode, bit_keyEntry0
	GOTO	PROCESS_KEYS_07_reset
	BTFSC	keymap_entryMode, bit_keyEntry1
	GOTO	PROCESS_KEYS_07_reset
	
	BSF	keymap_entryMode, bit_keyEntry1
	BCF	keymap_entryMode, bit_keySign
	
	CLRF	dro_offset0
	CLRF	dro_offset1
	CLRF	dro_offset2
	
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_07_reset:
	BCF	keymap_entryMode, bit_keyEntry0
	BCF	keymap_entryMode, bit_keyEntry1
	GOTO	PROCESS_KEYS_END



PROCESS_KEYS_08:
	; key 08[1]

	BTFSS	keymap_entryMode, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset0
	MOVLW	1
	IORWF	dro_offset0, F

	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_09:
	; key 09[2]

	BTFSS	keymap_entryMode, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset0
	MOVLW	2
	IORWF	dro_offset0, F

	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_10:
	; key 06[3]

	BTFSS	keymap_entryMode, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset0
	MOVLW	3
	IORWF	dro_offset0, F

	GOTO	PROCESS_KEYS_END

PROCESS_KEYS_11:

	; BTFSC	keymap_entryMode, bit_keyEntry0
	; GOTO	PROCESS_KEYS_11_reset
	; BTFSC	keymap_entryMode, bit_keyEntry1
	; GOTO	PROCESS_KEYS_11_reset
	
	; BSF	keymap_entryMode, bit_keyEntry2
	; CLRF	dro_offset0
	; CLRF	dro_offset1
	; CLRF	dro_offset2
	
	; GOTO	PROCESS_KEYS_END
	
; PROCESS_KEYS_11_reset:
	; BCF	keymap_entryMode, bit_keyEntry0
	; BCF	keymap_entryMode, bit_keyEntry1
	
	GOTO	PROCESS_KEYS_END	
	
	
PROCESS_KEYS_12:
	; key 12[*] for 1/2 function
	
		
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_13:
	; key 13[0]

	BTFSS	keymap_entryMode, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset0
	MOVLW	0
	IORWF	dro_offset0, F

	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_14:
	; key 14[-] for minus sign
	BTFSS	keymap_entryMode, bit_keyEntry
	GOTO	PROCESS_KEYS_END
	
	MOVLW	mask_keySign
	XORWF	keymap_entryMode, F
	
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_15:
	; key 15[D] for accept
	BTFSC	keymap_entryMode, bit_keyEntry0
	GOTO	PROCESS_KEYS_15_accept0
	BTFSC	keymap_entryMode, bit_keyEntry1
	GOTO	PROCESS_KEYS_15_accept1
	
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_15_accept0:
	SUBc	dro_offset0, dro0_0
	
	MOVF	dro_offset0, W
	MOVWF	dro0_offset0
	MOVF	dro_offset1, W
	MOVWF	dro0_offset1
	MOVF	dro_offset2, W
	MOVWF	dro0_offset2
	BCF	keymap_entryMode, bit_keyEntry0
	GOTO	PROCESS_KEYS_END

PROCESS_KEYS_15_accept1:
	SUBc	dro_offset1, dro0_1
	
	MOVF	dro_offset0, W
	MOVWF	dro1_offset0
	MOVF	dro_offset1, W
	MOVWF	dro1_offset1
	MOVF	dro_offset2, W
	MOVWF	dro1_offset2
	BCF	keymap_entryMode, bit_keyEntry1
	GOTO	PROCESS_KEYS_END
	
	
PROCESS_KEYS_END:
	BCF	keymap_entryMode, bit_keyEntry
	BTFSC	keymap_entryMode, bit_keyEntry0
	BSF	keymap_entryMode, bit_keyEntry
	BTFSC	keymap_entryMode, bit_keyEntry1
	BSF	keymap_entryMode, bit_keyEntry
	;BTFSC	keymap_entryMode, bit_keyEntry0
	;BSF	keymap_entryMode, bit_keyEntry
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
; EEPROM data byte at 0x01 is config_1
	DE	3	; display brightness
;#############################################################################
;	End Declaration
;#############################################################################

	END

	
	
	
	
	
	
	
	
