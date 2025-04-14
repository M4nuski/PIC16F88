;#############################################################################
;
;	Mill DRO control for chineese DRO scale
;	3 Axis
;	Display on 3 TM1637 6-digits 7-segments
;	Input with 5x4 keypad
;
;#############################################################################
;
;	Version 0
;	3 DRO scale sampling, display on 3 TM1637
;	SEG brightness in EEPROM config
;	
;	Convert from MM to INCHES (0.001)
;	Scale reverse in EEPROM config
;	//Output on UART at 9600 bauds
;	Keypad entry
; 
;RA6	O DispClk // common display clock
;RB7	O DispData0 // display data
;RB6	O DispData1
;RB5	O DispData2
;RA0	I DROclk0 // DRO serial inputs
;RA1	I DROdta0
;RA2	I DROclk1
;RA3	I DROdta1
;RA4	I DROclk2
;RA5	I DROdta2
;RB0	O KeypadSel0 // binary select line address 0 1 2 3
;RB1	O KeypadSel1
;RB2	I KeypadVal0 // binary value from pad 1 2 3 4 5 6 7 (0 is no keydown)
;RB3	I KeypadVal1
;RB4	I KeypadVal2
;
;RA7	20MHz clock
;
;	6 Outputs
;	9 Inputs
;	15 IO total
;
; baseline Program Memory Words Used:  1472
; merge display mm and display in Program Memory Words Used:  1392
; replaced bitset macro with rrfc Program Memory Words Used:  1356 (-8%)
; added input actual for both scale, inch to mm conversion : 1878
; simplified TM1637 start and stop 1886
; half function added : 2058
;
;;#############################################################################
;
;	mm to In
;	Set actual
;	Zero
;	Half function
;	
;	Test at 8MHz
;	Upgrade to 20MHz crystal if enough pins avaiable
;
;      Keypad Layout: (4 rows, 5 columns)
;
;      X   7   8   9   In/mm
;      Y   4   5   6   1/2
;      Z   1   2   3   
;          -   0       OK
;
;	select In/mm to switch between In/1000 and mm/100
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
; USB mini B connectors:
; |¯¯¯¯¯¯¯¯¯¯¯¯¯| 	|¯¯¯¯¯¯¯¯¯¯¯¯¯|
;  \ 1 2 3 4 5 /   	 | 5 4 3 2 1 |
;   |_________| 	 ¯¯¯¯¯¯¯¯¯¯¯¯
;     edge jack 	  cable plug
;
; DRO "USB" fake pinout:
; Pin 1 USB standard: VBUS RED			DRO: Data
; Pin 2 USB standard: DATA- WHITE		DRO: Clock
; Pin 3 USB standard: DATA+ GREEN		DRO: Ground
; Pin 4 USB standard: NC on device side		DRO: Power 1.5V-3.0V
; Pin 5 USB standard: GROUND BLACK		DRO: NC
; low of more than 0.5 ms is idle between 2 data packets
; 24 bit sync, LSB first, in 0.01 mm
; bit 20 is sign, max data is 20bits, or 10485.75mm
; 1.5V signal inverted trough NPN with 33K pullup and 1K between base and "USB" connector
;
; New "JST" connectors:
;  /¯-¯¯¯-¯\    __-___-__
; | 1 2 3 4 |  | 4 3 2 1 |
; |_________|  |_________|
;  edge jack   cable plug
;
; 1 +3.3V  (Black)
; 2 Clock  (White)
; 3 Data   (Red)
; 4 Ground (Green)
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
; 4x5 Keypad scanner with GAL20v8
;                               _______________
;                              |KEYPAD_SCAN_4x5|
;                     brs0 x---|1            24|---x Vcc                      
;                     brs1 x---|2            23|---x                          
;                          x---|3            22|---x bval2                    
;                          x---|4            21|---x bval1                    
;                          x---|5            20|---x bval0                    
;                          x---|6            19|---x                          
;                      cr0 x---|7            18|---x rsel3                    
;                      cr1 x---|8            17|---x rsel2                    
;                      cr2 x---|9            16|---x rsel1                    
;                      cr3 x---|10           15|---x rsel0                    
;                      cr4 x---|11           14|---x                          
;                      GND x---|12           13|---x                          
;                              |_______________|
;
; BSRx  : binary row select input
; BVALx : binary selected colunm output
; RSELx : row select lines (trough diodes)
; CRx   : colunm return lines (pulled low)
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

	__CONFIG	_CONFIG1, 	_CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_OFF & _PWRTE_OFF & _WDT_OFF & _INTRC_IO
	__CONFIG	_CONFIG2, 	_IESO_OFF & _FCMEN_OFF

;#############################################################################
;	Pinout
;#############################################################################

; PIC16F88:
; pin  1 IOA PORTA2	I Keypad data sense
; pin  2 IOA PORTA3	I DRO1 Data
; pin  3 IOA PORTA4	O Keypad Clock
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O DISP0 Data 
; pin  7 IO_ PORTB1	O DISP Clock
; pin  8 IOR PORTB2	I UART RX
; pin  9 IO_ PORTB3	O DISP1 Data

; pin 10 IO_ PORTB4	I UNIT SWITCH
; pin 11 IOT PORTB5	O UART TX
; pin 12 IOA PORTB6	I ICSP PGC
; pin 13 IOA PORTB7	I ICSP PGD
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O Keypad data pulse
; pin 16 I_X PORTA7	20MHz clock in ?  DRO1 Clock
; pin 17 IOA PORTA0	I DRO0 Data
; pin 18 IOA PORTA1	I DRO0 Clock


; V+ (square pad)
; Clock
; E
; Data
; GND

#DEFINE pin_DRO0_CLOCK	PORTA, 0
mask_DRO0_CLOCK		EQU	0x01
#DEFINE pin_DRO0_DATA	PORTA, 1
mask_DRO0_DATA		EQU	0x02
#DEFINE pin_DRO1_CLOCK	PORTA, 2
mask_DRO1_CLOCK		EQU	0x04
#DEFINE pin_DRO1_DATA	PORTA, 3
mask_DRO1_DATA		EQU	0x08
#DEFINE pin_DRO2_CLOCK	PORTA, 4
mask_DRO2_CLOCK		EQU	0x10
#DEFINE pin_DRO2_DATA	PORTA, 5
mask_DRO2_DATA		EQU	0x20

#DEFINE pin_DISP_CLOCK	PORTA, 6
;#DEFINE pin_OSC_IN	PORTA, 7

#DEFINE pin_KEYPAD_SEL0	PORTB, 0
#DEFINE pin_KEYPAD_SEL1	PORTB, 1
#DEFINE pin_KEYPAD_VAL0	PORTB, 2
#DEFINE pin_KEYPAD_VAL1	PORTB, 3
#DEFINE pin_KEYPAD_VAL2	PORTB, 4

#DEFINE pin_DISP2_DATA	PORTB, 5
#DEFINE pin_DISP1_DATA	PORTB, 6
#DEFINE pin_DISP0_DATA	PORTB, 7

; EEPROM data byte at 0x00 is config
; bit 0-3 x2 axis 0-3 (for radius to diameter direct reading)
; bit 4-7 is reverse axis direction


;#############################################################################
;	Memory Organisation
;#############################################################################

; Bank #    SFR           GPR               SHARED GPR's		total 368 bytes of GPR, 16 shared between banks
; Bank 0    0x00-0x1F     0x20-0x7F         target area 0x70-0x7F	96
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

; raw DRO data, 2's complement
dro0_0			EQU	0x24
dro0_1			EQU	0x25
dro0_2			EQU	0x26

dro1_0			EQU	0x27
dro1_1			EQU	0x28
dro1_2			EQU	0x29

dro2_0			EQU	0x2A
dro2_1			EQU	0x2B
dro2_2			EQU	0x2C

keypad_key		EQU	0x2D
keypad_last		EQU	0x2E
bit_keyUp		EQU	6
bit_keyRepeat		EQU	7

keypad_status		EQU	0x2F
bit_keyEntry0		EQU	0	; entering dro0 actual
bit_keyEntry1		EQU	1	; entering dro1 actual
bit_keyEntry2		EQU	2	; entering dro2 actual
bit_keyEntry		EQU	3	; entering actual
bit_keySign		EQU	6	; entering sign
mask_keySign		EQU	0x40
bit_keySwitchLast	EQU	7	; unit switch last state

; current entry packed BCD with sign bit in entry 
dro_offset_0		EQU	0x30
dro_offset_1		EQU	0x31
dro_offset_2		EQU	0x32

; offset for DRO data, 2's complement
dro0_offset_0		EQU	0x33
dro0_offset_1		EQU	0x34
dro0_offset_2		EQU	0x35

dro1_offset_0		EQU	0x36
dro1_offset_1		EQU	0x37
dro1_offset_2		EQU	0x38

dro2_offset_0		EQU	0x39
dro2_offset_1		EQU	0x3A
dro2_offset_2		EQU	0x3B

; current data
; in 100th of mm, sign in status bit
data_f			EQU	0x3C
data_0			EQU	0x3D
data_1			EQU	0x3E
data_2			EQU	0x3F
data_3			EQU	0x40
bit_dataSign		EQU	4
mask_dataSign		EQU	0x10

accum_0			EQU	0x41
accum_1			EQU	0x42
accum_2			EQU	0x43
accum_3			EQU	0x44

;			EQU	0x45
;			EQU	0x46
;			EQU	0x47

data_status		EQU	0x48
bit_statusDRO0Sign	EQU	0
bit_statusDRO1Sign	EQU	1
bit_statusDRO2Sign	EQU	2
;bit_status		EQU	3
bit_statusSign		EQU	4
mask_statusSign		EQU	0x10 
bit_statusUnit		EQU	5 ; 0:mm, 1:In
mask_statusUnit		EQU	0x20 
bit_statusSuppressD3	EQU	6
bit_statusSuppressD4	EQU	7

;			EQU	0x49

; packed BCD of data for display
data_BCD0		EQU	0x4A
data_BCD1		EQU	0x4B
data_BCD2		EQU	0x4C
data_BCD3		EQU	0x4D; could be ignored, overflow of binary to BCD conversion
; max display length -99.999 inches
; max display length -999.99 mm (1 m)
; max of 20 bit 10485.75

mask_DRO_Clock		EQU	0x4E
mask_DRO_Data		EQU	0x4F

disp_currentSetMask	EQU	0x50
disp_currentClearMask	EQU	0x51
disp_buffer		EQU	0x52
PORTB_buffer		EQU	0x53

;			EQU	0x54
;			EQU	0x55
;			EQU	0x56
;			EQU	0x57
;			EQU	0x58
;			EQU	0x59
;			EQU	0x5A
;			EQU	0x5B
;			EQU	0x5C
;			EQU	0x5D
;			EQU	0x5E
;			EQU	0x5F

CFG			EQU	0x60	; axix X2 and reverse
;bit_CFGdia0		EQU	0
;bit_CFGdia1		EQU	1
;bit_CFGdia2		EQU	2
;bit_CFGdia		EQU	3 ; current for selected dro ; TODO remove for MILL
bit_CFGreverse0		EQU	4
bit_CFGreverse1		EQU	5
bit_CFGreverse2		EQU	6
bit_CFGreverse		EQU	7 ; current for selected dro
CFG_1			EQU	0x61	; display brightness

;			EQU	0x62
;			EQU	0x63
;			EQU	0x64
;			EQU	0x65
;			EQU	0x66
;			EQU	0x67
;			EQU	0x68
;			EQU	0x69
;			EQU	0x6A
temp_f			EQU	0x6B ; temporaries for arithmetics
temp_0			EQU	0x6C
temp_1			EQU	0x6D
temp_2			EQU	0x6E
;			EQU	0x6F		

; TM1637 line output masks:
#DEFINE ClockClear	b'11111101'
#DEFINE ClockSet	b'00000010'

#DEFINE Data0Clear	b'11111110'
#DEFINE Data0Set	b'00000001'

#DEFINE Data1Clear	b'11110111'
#DEFINE Data1Set	b'00001000'

#DEFINE Data2Clear	b'11110111'
#DEFINE Data2Set	b'00001000'

; TM1637 commands:
#DEFINE _Data_Write	b'01000000'
#DEFINE _Address_C3H	b'11000011'
#DEFINE _Display_ON	b'10001000'
#DEFINE _Display_OFF	b'10000000'

#DEFINE	_LCD_Char_dot	0x10
#DEFINE	_LCD_Char_minus	0x11
#DEFINE	_LCD_Char_r	0x12
#DEFINE	_LCD_Char_o	0x13

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
	; inline 5us (10 inst cycles) ; TODO update to 20MHz
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
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
	
SwitchData2	MACRO
	MOVLW	Data2Clear
	MOVWF	disp_currentClearMask
	MOVLW	Data2Set
	MOVWF	disp_currentSetMask
	ENDM

RNLc	MACRO	file
	LOCAL	_top
	MOVLW	256 - 4 ; 252 253 254 255 
_top:	
	BCF	STATUS, C
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	ADDLW	1 ; 253 254 255 256
	BTFSS	STATUS, Z
	GOTO	_top
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
	BSF	pin_DRO2_CLOCK	; input
	BSF	pin_DRO2_DATA	; input
	
	BSF	pin_KEYPAD_VAL0  ; input
	BSF	pin_KEYPAD_VAL1  ; input
	BSF	pin_KEYPAD_VAL2  ; input

	; init osc 8MHz ; TODO ignore for external 20MHz
	BCF	OSCCON, SCS0
	BCF	OSCCON, SCS1
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
	BTFSS	OSCCON, IOFS
	GOTO	$-1
	
	; UART at 9600, 8 bits, async
	; ;BSF	TXSTA, CSRC	; not used in async - set as clock source master
	; BCF 	TXSTA, TX9	; 8 bit tx
	; BSF	TXSTA, TXEN	; enable tx
	; BCF	TXSTA, SYNC	; async
	
	; ; set 9600 baud rate
	; BSF 	TXSTA, BRGH	; high speed baud rate generator	
	; MOVLW	51		; 9600 bauds
	; MOVWF	SPBRG
	
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
	; pre scaler is 1:4, overlfow of 65536 instructions cycles is 131ms ; TODO update to 20MHz
	BCF	T1CON, TMR1CS	; timer1 clock is FOSC/4
	BSF	T1CON, TMR1ON	; timer1 ON
	
	; UART
	;BSF	RCSTA, SPEN	; serial port enabled

; enable interrupts
	BCF	INTCON, PEIE ; enable peripheral int
	BCF	INTCON, TMR0IF; clear flag
	BCF	INTCON, TMR0IE; enable tmr0 interrupt
	CLRF	TMR0; clear tmr0

	BCF	INTCON, GIE
	
;#############################################################################
;	Program start 
;#############################################################################
	MOVLW	HIGH (WAIT_50ms)
	MOVWF	PCLATH
	CALL	WAIT_50ms
MAIN:

	Peek_PORTB;;; TODO replace portb Macro with direct writes
	
	Pin_Clk_UP
	
	disp_select0
	Pin_Data_UP
	disp_select1
	Pin_Data_UP
	disp_select2
	Pin_Data_UP
	
	Update_PORTB
	
	STR 15, CFG_1
	
	disp_select0
	CALL	TM1637_PREFACE	

	ARRAYl	table_hexTo7seg, 0
	CALL	TM1637_data
	
	ARRAYl	table_hexTo7seg, 0
	IORLW	0x80
	CALL	TM1637_data
	
	;ARRAYl	table_hexTo7seg, 0
	CLRW
	CALL	TM1637_data

	ARRAYl	table_hexTo7seg, _LCD_Char_o
	CALL	TM1637_data
	
	ARRAYl	table_hexTo7seg, _LCD_Char_r
	CALL	TM1637_data
	
	ARRAYl	table_hexTo7seg, 0x0d
	CALL	TM1637_data
	
	CALL	TM1637_ANNEX
	
	
	disp_select1	
	CALL	TM1637_PREFACE		

	ARRAYl	table_hexTo7seg, 0x05
	CALL	TM1637_data
	
	ARRAYl	table_hexTo7seg, 0x02
	CALL	TM1637_data
	
	ARRAYl	table_hexTo7seg, 0x00
	CALL	TM1637_data

	ARRAYl	table_hexTo7seg, 0x02
	CALL	TM1637_data
	
	ARRAYl	table_hexTo7seg, 0x0C
	CALL	TM1637_data
	
	ARRAYl	table_hexTo7seg, 0x0E
	CALL	TM1637_data

	CALL	TM1637_ANNEX
	
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

	CLRF	data_status
	CLRF	keypad_status
	BCF	keypad_status, bit_keySwitchLast
	CLRF	keypad_key
	CLRF	keypad_last
	
	CLRFc	dro0_offset_0
	CLRFc	dro1_offset_0
	CLRFc	dro2_offset_0

	MOVLW	20
	MOVWF	loop_count
main_wait:
	MOVLW	HIGH (WAIT_50ms)
	MOVWF	PCLATH
	CALL	WAIT_50ms
	DECFSZ	loop_count, F
	GOTO	main_wait
	
;#############################################################################
;	Program Loop
;#############################################################################

LOOP:
	BTFSC	keypad_status, bit_keyEntry
	GOTO	DRO0_done
	
; ACQ DRO 0
	STR	mask_DRO0_CLOCK, mask_DRO_Clock
	STR	mask_DRO0_DATA, mask_DRO_Data	
	; BCF	CFG, bit_CFGdia
	; BTFSC	CFG, bit_CFGdia0
	; BSF	CFG, bit_CFGdia	
	BCF	CFG, bit_CFGreverse
	BTFSC	CFG, bit_CFGreverse0
	BSF	CFG, bit_CFGreverse
	
	CALL	ACQ_DRO
	
	BW_False	DRO0_done
	MOVc	data_0, dro0_0	
	ADDc	data_0, dro0_offset_0
	
	BTFSS	data_2, 7
	GOTO	DRO0_done

	BSF	data_status, bit_statusSign
	NEGc	data_0

DRO0_done:
	disp_select0; first display
	
	BTFSS	keypad_status, bit_keyEntry1
	GOTO	DRO0_disp

	CALL	DISPLAYCLEAR
	BSF	PCLATH, 3
	CALL	PROCESS_KEYS
	GOTO	ACQ_DRO1

DRO0_disp:
	CALL	DISPLAY7segs
	BSF	PCLATH, 3
	CALL	PROCESS_KEYS

	BTFSC	keypad_status, bit_keyEntry
	GOTO	DRO1_done


; ACQ DRO 1
ACQ_DRO1:
	STR	mask_DRO1_CLOCK, mask_DRO_Clock
	STR	mask_DRO1_DATA, mask_DRO_Data	
	; BCF	CFG, bit_CFGdia
	; BTFSC	CFG, bit_CFGdia1
	; BSF	CFG, bit_CFGdia	
	BCF	CFG, bit_CFGreverse
	BTFSC	CFG, bit_CFGreverse1
	BSF	CFG, bit_CFGreverse
	
	CALL	ACQ_DRO
	
	BW_False	DRO1_done
	MOVc	data_0, dro1_0	
	ADDc	data_0, dro1_offset_0

	BTFSS	data_2, 7
	GOTO	DRO1_done

	BSF	data_status, bit_statusSign
	NEGc	data_0	

DRO1_done:
	disp_select1; second display
	
	BTFSS	keypad_status, bit_keyEntry0
	GOTO	DRO1_disp

	CALL	DISPLAYCLEAR
	BSF	PCLATH, 3
	CALL	PROCESS_KEYS
	GOTO	LOOP

DRO1_disp:
	CALL	DISPLAY7segs
	BSF	PCLATH, 3
	CALL	PROCESS_KEYS
	
	GOTO	LOOP



;#############################################################################
;	SUBROUTINES
;#############################################################################


ACQ_DRO:
	MOVLW	0x80
	XORWF	PORTB, F
	
	; reset tmr1 for timeout
	CLRF	TMR1H
	CLRF	TMR1L
	BCF	PIR1, TMR1IF
ACQ_DRO_0:
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	RETLW	FALSE
	
	MOVF	mask_DRO_Clock, W ; wait for clock low
	ANDWF	PORTA, W
	BTFSS	STATUS, Z
	GOTO	ACQ_DRO_0
	CLRF	TMR0		; clear tmr0
	BCF	INTCON, TMR0IF	; clear flag
ACQ_DRO_1:

	MOVF	mask_DRO_Clock, W ; check if clock high
	ANDWF	PORTA, W
	BTFSS	STATUS, Z
	GOTO	ACQ_DRO_0	; reacquire if under 1ms of idle
	
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	RETLW	FALSE
	
	BTFSS	INTCON, TMR0IF
	GOTO	ACQ_DRO_1

	CLRFc	data_0
	BCF	data_status, bit_statusSign
	STR	24, loop_count
	
READ_DRO_loop1:
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	RETLW	FALSE
	
	MOVF	mask_DRO_Clock, W ;wait for clock up
	ANDWF	PORTA, W
	BTFSC	STATUS, Z
	GOTO	READ_DRO_loop1

READ_DRO_loop2:
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	RETLW	FALSE
	
	MOVF	mask_DRO_Clock, W ; wait for clock down
	ANDWF	PORTA, W
	BTFSS	STATUS, Z
	GOTO	READ_DRO_loop2
	
	BCF	STATUS, C
	MOVF	mask_DRO_Data, W ; bits are inverted in input level transistor
	ANDWF	PORTA, W
	BTFSC	STATUS, Z
	BSF	STATUS, C
	RRFc	data_0

	DECFSZ	loop_count, F
	GOTO	READ_DRO_loop1
	
	; apply config
	BTFSS	CFG, bit_CFGreverse
	GOTO	DRO_noReverse	
	
	MOVLW	mask_dataSign
	XORWF	data_2, F

DRO_noReverse:	
	BTFSS	data_2, bit_dataSign
	RETLW	TRUE; GOTO	DRO_notNegative	
	
	BCF	data_2, bit_dataSign ; clear old bit
	NEGc	data_0	; 2's complement
	
	RETLW	TRUE
; DRO_notNegative:
	; ; apply config
	; BTFSS	CFG, bit_CFGdia
	; RETLW	TRUE

 	; BCF	STATUS, C
	; RLFc	data_0
	
	; RETLW	TRUE
	
;#############################################################################
;	DISPLAY 7 segs
;#############################################################################
	
DISPLAY7segs:
	BTFSC	data_status, bit_statusUnit 
	CALL	DIV_2p54
	
	; clear digit 3 and 4 suppress bits	
	BCF	data_status, bit_statusSuppressD4
	BCF	data_status, bit_statusSuppressD3
	
	BTFSS	keypad_status, bit_keyEntry
	GOTO	DISPLAY7segs_bin2BCD
	
	MOVc	dro_offset_0, data_BCD0
	
	BCF	data_status, bit_statusSign
	BTFSC	keypad_status, bit_keySign
	BSF	data_status, bit_statusSign
	GOTO	DISPLAY7segs_checkSupp

DISPLAY7segs_bin2BCD:	
	; binary to packed BCD	
	MOVLW	HIGH (BCD20)
	MOVWF	PCLATH
	CALL	BCD20

DISPLAY7segs_checkSupp:
	; check if 2 last digits need to be suppressed (leading 0s)
	MOVF	data_BCD2, W
	ANDLW	0x0F
	BTFSS	STATUS, Z
	GOTO	DISPLAY7segs_check0
	BSF	data_status, bit_statusSuppressD4
	SWAPF	data_BCD1, W
	ANDLW	0x0F
	BTFSC	STATUS, Z
	BSF	data_status, bit_statusSuppressD3
	
	BTFSC	data_status, bit_statusUnit 
	BCF	data_status, bit_statusSuppressD3	; never suppress D3 in IN mode
	
DISPLAY7segs_check0:
	; check if minus sign need to be suppressed
	MOVF	data_BCD0, F
	BTFSS	STATUS, Z
	GOTO	DISPLAY7segs_disp
	MOVF	data_BCD1, F
	BTFSS	STATUS, Z
	GOTO	DISPLAY7segs_disp
	MOVF	data_BCD2, F
	BTFSS	STATUS, Z
	GOTO	DISPLAY7segs_disp
	BTFSS	keypad_status, bit_keyEntry ; display anyway if in entry mode
	BCF	data_status, bit_statusSign
	 
DISPLAY7segs_disp:
	CALL	TM1637_PREFACE
	
	MOVLW	HIGH (table_hexTo7seg)
	MOVWF	PCLATH
	
	MOVF	data_BCD0, W ; s0000.0x
	ANDLW	0x0F
	CALL	table_hexTo7seg
	CALL	TM1637_data
	
	SWAPF	data_BCD0, W ; s0000.x0
	ANDLW	0x0F
	CALL	table_hexTo7seg
	CALL	TM1637_data	
	
	MOVF	data_BCD1, W ; s000x.00
	ANDLW	0x0F
	CALL	table_hexTo7seg
	BTFSS	data_status, bit_statusUnit
	IORLW	0x80; disp_buffer, 7 ; dot	for mm
	CALL	TM1637_data
	
	SWAPF	data_BCD1, W ; s00x0.00
	ANDLW	0x0F
	CALL	table_hexTo7seg
	BTFSC	data_status, bit_statusSuppressD3
	CLRW
	BTFSC	data_status, bit_statusUnit
	IORLW	0x80; BSF	disp_buffer, 7 ; dot for in
	CALL	TM1637_data
	

	MOVF	data_BCD2, W ; s00x0.00
	ANDLW	0x0F
	CALL	table_hexTo7seg
	BTFSC	data_status, bit_statusSuppressD4
	CLRW
	CALL	TM1637_data
	
	MOVLW	b'01000000';-
	BTFSS	data_status, bit_statusSign
	CLRW
	CALL	TM1637_data
	
	CALL	TM1637_ANNEX
	
	RETURN

DISPLAYCLEAR:
	CALL	TM1637_PREFACE

	MOVLW	6
	MOVWF	loop_count_2
DISPLAYCLEAR_loop:
	CLRW
	CALL	TM1637_data
	DECFSZ	loop_count_2, F
	GOTO	DISPLAYCLEAR_loop
	
	CALL	TM1637_ANNEX
	
	RETURN

	
;#############################################################################
; TM1637 6digits x 7segments displays
;#############################################################################
TM1637_PREFACE:
	Peek_PORTB
	Pin_Data_DOWN
	Update_PORTB
	
	MOVLW	_Data_Write
	CALL	TM1637_data
	
	Pin_Data_DOWN
	Update_PORTB
	Pin_Clk_UP
	Update_PORTB
	Pin_Data_UP
	Update_PORTB
	inline_50us
	
	Pin_Data_DOWN
	Update_PORTB
	
	MOVLW	_Address_C3H
	CALL	TM1637_data
	RETURN
	
;loop version
TM1637_data:	; data is in W;
	MOVWF	disp_buffer
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

TM1637_ANNEX:
	Pin_Data_DOWN
	Update_PORTB
	Pin_Clk_UP
	Update_PORTB
	Pin_Data_UP
	Update_PORTB
	inline_50us
	
	Pin_Data_DOWN
	Update_PORTB
	
	MOVF	CFG_1, W
	IORLW	_Display_ON
	CALL	TM1637_data
	
	Pin_Data_DOWN
	Update_PORTB
	Pin_Clk_UP
	Update_PORTB
	Pin_Data_UP
	Update_PORTB
	inline_50us
	
	RETURN


;#############################################################################
;	MATH!
;#############################################################################


;#############################################################################
;	24 bit binary to Packed BCD
;#############################################################################

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
;	BCD to 20 bits
;	max is 99999 or 0x01869F
;	Data in data_BCD2.data_BCD1.data_BCD0
;	Output in data_2.data_1.data_0
;	Temporary accum_2.accum_1.accum_0
;#############################################################################

BCD2BIN:
	CLRFc	data_0
	
	MOVLW	0x0F
	ANDWF	data_BCD2, W ;	select low nibble
	MOVWF	data_0
	CALL	BCD2BIN_x10
	
	SWAPF	data_BCD1, W
	ANDLW	0x0F
	CALL	BCD2BIN_addW_x10
	
	MOVF	data_BCD1, W
	ANDLW	0x0F
	CALL	BCD2BIN_addW_x10
	
	SWAPF	data_BCD0, W
	ANDLW	0x0F
	CALL	BCD2BIN_addW_x10
	
	MOVF	data_BCD0, W
	ANDLW	0x0F
	ADDWF	data_0, F
	BTFSS	STATUS, C
	RETURN
	INCF	data_1, F
	BTFSC	STATUS, Z
	INCF	data_2, F
	
	RETURN
	
BCD2BIN_addW_x10:
	ADDWF	data_0, F
	BTFSS	STATUS, C
	GOTO	BCD2BIN_x10
	INCF	data_1, F
	BTFSC	STATUS, Z
	INCF	data_2, F	

BCD2BIN_x10:	; multiply data x 10
	BCF	STATUS, C
	RLFc	data_0 ; x2
	MOVc	data_0, accum_0
	
	BCF	STATUS, C
	RLFc	data_0 ; x4
	BCF	STATUS, C
	RLFc	data_0 ; x8
	ADDc	data_0, accum_0 ; data = data*8 + data*2
	RETURN


;#############################################################################
;	div data / 2.54
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
	GOTO	DIV_2p54_0
	INCFc	data_0		; round up	
DIV_2p54_0:
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
	GOTO	DIV_2p54_1
	INCFc	data_0		; round up	
DIV_2p54_1:
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
;	mult data x 2.54
;	input in data_2.data_1.data_0
;	output in data_2.data_1.data_0
;	temporary in accum_3.accum_2.accum_1.accum_0
;			data_3.data_f
;			temp_2.temp_1.temp_0.temp_f
;#############################################################################
MULT_2p54:

	CLRF	data_3
	MOV	data_2, accum_3
	MOV	data_1, accum_2
	MOV	data_0, accum_1
	CLRF	accum_0		 ; accum = data x 256

	BCF	STATUS, C	
	RLFi	data_0		 ; data = data x 2
	SUBi	accum_0, data_0 ; accum = (data*256) - (data*2) = data*254

; DIV 100
; 128	512	4096	-131072	-524288	-4194304
; all rounded up 
;         no shift,	1byte,	2byte
; no bit shift  /1	/256	/64k	0
; after /2      /2	/512*	/128k*	1
; after /4      /4	/1024	/256k	2
; after /8      /8	/2k	/512k*	3
; after /16	 /16	/4k*	/1m	4
; after /32	 /32	/8k	/2m	5
; after /64	 /64	/16k	/4m*	6
; after /128*	/128	/32k	/8m	7
; after /256 	/256	/64k	/16m	byte shift

	; for rounding 
	CLRF	temp_f
	CLRF	temp_0
	CLRF	temp_1
	CLRF	temp_2

	MOV	accum_0, data_f
	MOV	accum_1, data_0
	MOV	accum_2, data_1
	MOV	accum_3, data_2
	CLRF	data_3
	; data = data/256
	
	BCF	STATUS, C
	RLFi	data_f
	MOVi	data_f, temp_f
	; data = data/256 * 2 == data / 128
	BTFSS	temp_f,  7
	GOTO 	MULT_2p54_1
	INCFc	temp_0		; temp = round (data/128)
MULT_2p54_1:
	MOVc	temp_0, accum_0 ;accum = Round(data / 128)
	
	BCF	STATUS, C
	RRFi	data_f ;/2  data = data / 256
	BCF	STATUS, C
	RRFi	data_f ;/2  data = data / 512
	MOVi	data_f, temp_f
	
	BTFSS	temp_f,  7	; round up
	GOTO 	MULT_2p54_2
	INCFc	temp_0		; temp = round(data/512)
MULT_2p54_2:
	ADDc	accum_0, temp_0 ;accum = Round(data / 128) + Round(data/512)
	

	MOVi	data_0, temp_f ; temp = data / 512 / 256 = data / 128k
	BTFSS	temp_f,  7	; round up
	GOTO 	MULT_2p54_3
	INCFc	temp_0		; temp = round(data/128k)
MULT_2p54_3:
	SUBc	accum_0, temp_0 ; accum = Round(data/128) + Round(data/512) - Round(data/128k)
	
	BCF	STATUS, C
	RRFi	data_f ;/2  data = data / 1024
	BCF	STATUS, C
	RRFi	data_f ;/2  data = data / 2k

	MOVc	data_0, temp_f ; temp = data / 2k / 256 = data / 512k
	BTFSS	temp_f,  7	; round up
	GOTO 	MULT_2p54_4
	INCFc	temp_0		; temp = round(data/512k)
MULT_2p54_4:
	SUBc	accum_0, temp_0 ; accum = Round(data/128) + Round(data/512) - Round(data/128k) - Round(data/512k)
	
	BCF	STATUS, C
	RRFi	data_f ;/2  data = data /4k
	
	MOVi	data_f, temp_f ; temp = data / 2k / 256 = data / 512k
	BTFSS	temp_f,  7	; round up
	GOTO 	MULT_2p54_5
	INCFc	temp_0		; temp = round(data/4k)
MULT_2p54_5:
	ADDc	accum_0, temp_0 ;accum = Round(data/128) + Round(data/512) - Round(data/128k) - Round(data/512k) + Round(data/4k)

	BCF	STATUS, C
	RRFi	data_f ;/2  data = data /8k
	
	BCF	STATUS, C
	RRFi	data_f ;/2  data = data /16k
	
	MOVi	data_0, temp_f ; temp = data /16k /256 = data / 4m
	
	BTFSS	temp_f,  7	; round up
	GOTO 	MULT_2p54_6
	INCFc	temp_0		; temp = round(data/4k)
MULT_2p54_6:
	SUBc	accum_0, temp_0 ;accum = Round(data/128) + Round(data/512) - Round(data/128k) - Round(data/512k) + Round(data/4k) - Round(data/4m)
	
	MOVc	accum_0, data_0
	
	RETURN
	

;#############################################################################
;	Tables
;#############################################################################

	PC0x0100SKIP; align to next 256 byte boundary in program memory
	
; ; nibble to char
; table_nibbleHex:
	; ADDWF	PCL, F
	; dt	"0123456789ABCDEF"

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
	RETLW	b'10000000';. 0x10
	RETLW	b'01000000';- 0x11
	RETLW	b'01010000';r 0x12
	RETLW	b'01011100';o 0x13
	
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
;	PC High Byte Boundary skip
;#############################################################################

	ORG	0x0800
	
;#############################################################################
;	KEYPAD
;#############################################################################

PROCESS_KEYS:
	BTFSC	keypad_status, bit_keyEntry	; skip unit toggle in entry mode
	GOTO	PROCESS_KEYS_s1
	
	BTFSC	pin_SWITCH		; clear when pressed
	GOTO	PROCESS_KEYS_sUp
	
PROCESS_KEYS_sSown:
	; check if already down
	BTFSS	keypad_status, bit_keySwitchLast
	GOTO	PROCESS_KEYS_s1	

	MOVLW	mask_statusUnit
	XORWF	data_status, F	; toggle current unit bit
	;MOVLW	'K'
	;CALL	SEND_BYTE
	;MOVF	data_status, W	
	;CALL	SEND_BYTE
	BCF	keypad_status, bit_keySwitchLast
	GOTO	PROCESS_KEYS_s1
	
PROCESS_KEYS_sUp:
	BSF	keypad_status, bit_keySwitchLast
	
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

	MOVF	keypad_key, W
	MOVWF	keypad_last
	BCF	keypad_last, bit_keyRepeat
	
;#############################################################################
;	Process Commands
;#############################################################################

	
	; MOVF	keypad_key, W
; SEND_BYTEcmd:	; send byte to UART, blocking
	; BTFSS	PIR1, TXIF
	; GOTO	SEND_BYTEcmd
	; MOVWF	TXREG

	MOVLW	15 ; TODO update to 4x5
	SUBWF	keypad_key, W
	BR_GT	PROCESS_KEYS_END
	

	PC0x0100SKIP
	MOVLW	HIGH (PROCESS_KEYS_00)
	MOVWF	PCLATH

; from PCB version 1.1 ; TODO update to 4x5 keypad
;
;	15[1]	11[2]	7 [3]	3 [A]
;	14[4]	10[5]	6 [6]	2 [B]
;	13[7]	9 [8]	5 [9]	1 [C]
;	12[*]	8 [0]	4 [#]	0 [D]
;

	MOVF	keypad_key, W
	ADDWF	PCL, F
	GOTO	PROCESS_KEYS_15
	GOTO	PROCESS_KEYS_11
	GOTO	PROCESS_KEYS_07
	GOTO	PROCESS_KEYS_03
	
	GOTO	PROCESS_KEYS_14
	GOTO	PROCESS_KEYS_10
	GOTO	PROCESS_KEYS_06
	GOTO	PROCESS_KEYS_02
	
	GOTO	PROCESS_KEYS_13
	GOTO	PROCESS_KEYS_09
	GOTO	PROCESS_KEYS_05
	GOTO	PROCESS_KEYS_01
	
	GOTO	PROCESS_KEYS_12
	GOTO	PROCESS_KEYS_08
	GOTO	PROCESS_KEYS_04
	GOTO	PROCESS_KEYS_00

	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_00:
	; key 00[7]
	BTFSS	keypad_status, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset_0
	MOVLW	7
	IORWF	dro_offset_0, F

	GOTO	PROCESS_KEYS_END
PROCESS_KEYS_01:
	; key 01[8]
	BTFSS	keypad_status, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset_0
	MOVLW	8
	IORWF	dro_offset_0, F

	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_02:
	; key 00[9]
	BTFSS	keypad_status, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset_0
	MOVLW	9
	IORWF	dro_offset_0, F

	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_03:
	; key 03[A] for DRO0 select

	BTFSC	keypad_status, bit_keyEntry
	GOTO	PROCESS_KEYS_03_reset
	
	BSF	keypad_status, bit_keyEntry
	BSF	keypad_status, bit_keyEntry0
	BCF	keypad_status, bit_keySign

	CLRF	dro_offset_0
	CLRF	dro_offset_1
	CLRF	dro_offset_2
	
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_03_reset:
	BCF	keypad_status, bit_keyEntry
	BCF	keypad_status, bit_keyEntry0
	BCF	keypad_status, bit_keyEntry1
	BCF	keypad_status, bit_keyEntry2
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_04:
	; key 04[4]
	BTFSS	keypad_status, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset_0
	MOVLW	4
	IORWF	dro_offset_0, F

	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_05:
	; key 05[5]
	BTFSS	keypad_status, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset_0
	MOVLW	5
	IORWF	dro_offset_0, F

	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_06:
	; key 06[6]

	BTFSS	keypad_status, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset_0
	MOVLW	6
	IORWF	dro_offset_0, F

	GOTO	PROCESS_KEYS_END

PROCESS_KEYS_07:	
	; key 07[B] for DRO1 select
	
	BTFSC	keypad_status, bit_keyEntry
	GOTO	PROCESS_KEYS_07_reset
	
	BSF	keypad_status, bit_keyEntry
	BSF	keypad_status, bit_keyEntry1
	BCF	keypad_status, bit_keySign

	CLRF	dro_offset_0
	CLRF	dro_offset_1
	CLRF	dro_offset_2
	
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_07_reset:
	BCF	keypad_status, bit_keyEntry 
	BCF	keypad_status, bit_keyEntry0
	BCF	keypad_status, bit_keyEntry1
	BCF	keypad_status, bit_keyEntry2
	GOTO	PROCESS_KEYS_END



PROCESS_KEYS_08:
	; key 08[1]

	BTFSS	keypad_status, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset_0
	MOVLW	1
	IORWF	dro_offset_0, F

	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_09:
	; key 09[2]

	BTFSS	keypad_status, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset_0
	MOVLW	2
	IORWF	dro_offset_0, F

	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_10:
	; key 06[3]

	BTFSS	keypad_status, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset_0
	MOVLW	3
	IORWF	dro_offset_0, F

	GOTO	PROCESS_KEYS_END

PROCESS_KEYS_11:

	GOTO	PROCESS_KEYS_END
	; NOT IMPLEMENTED
	; BTFSC	keypad_status, bit_keyEntry
	; GOTO	PROCESS_KEYS_11_reset
	
	; BSF	keypad_status, bit_keyEntry
	; BSF	keypad_status, bit_keyEntry2
	; BCF	keypad_status, bit_keySign

	; CLRF	dro_offset_0
	; CLRF	dro_offset_1
	; CLRF	dro_offset_2
	
	; GOTO	PROCESS_KEYS_END
	
; PROCESS_KEYS_11_reset:
	; BCF	keypad_status, bit_keyEntry 
	; BCF	keypad_status, bit_keyEntry0
	; BCF	keypad_status, bit_keyEntry1
	; BCF	keypad_status, bit_keyEntry2
	; GOTO	PROCESS_KEYS_END
	
	
	
PROCESS_KEYS_12:
	; key 12[*] for 1/2 function
	BTFSS	keypad_status, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	
	BCF	keypad_status, bit_keyEntry 
	
	BTFSC	keypad_status, bit_keyEntry0
	GOTO	PROCESS_KEYS_12_dro0
	BTFSC	keypad_status, bit_keyEntry1
	GOTO	PROCESS_KEYS_12_dro1
	BTFSC	keypad_status, bit_keyEntry2
	GOTO	PROCESS_KEYS_12_dro2	
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_12_dro0:
	MOVc	dro0_0, data_0
	ADDc	data_0, dro0_offset_0
	BCF	STATUS, C
	RRFc	data_0	
	BTFSC	data_2, 6
	BSF	data_2, 7
	SUBc	data_0, dro0_0	
	MOVc	data_0, dro0_offset_0
 		
	BCF	keypad_status, bit_keyEntry0
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_12_dro1:
	MOVc	dro1_0, data_0
	ADDc	data_0, dro1_offset_0
	BCF	STATUS, C
	RRFc	data_0	
	BTFSC	data_2, 6
	BSF	data_2, 7
	SUBc	data_0, dro1_0	
	MOVc	data_0, dro1_offset_0
		
	BCF	keypad_status, bit_keyEntry1
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_12_dro2:
	MOVc	dro2_0, data_0
	ADDc	data_0, dro2_offset_0
	BCF	STATUS, C
	RRFc	data_0	
	BTFSC	data_2, 6
	BSF	data_2, 7
	SUBc	data_0, dro2_0	
	MOVc	data_0, dro2_offset_0
	BCF	keypad_status, bit_keyEntry2
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_13:
	; key 13[0]

	BTFSS	keypad_status, bit_keyEntry
	GOTO	PROCESS_KEYS_END	
	RNLc	dro_offset_0
	MOVLW	0
	IORWF	dro_offset_0, F

	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_14:
	; key 14[-] for minus sign
	BTFSS	keypad_status, bit_keyEntry
	GOTO	PROCESS_KEYS_END
	
	MOVLW	mask_keySign
	XORWF	keypad_status, F
	
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_15:
	; key 15[D] for accept

	BTFSS	keypad_status, bit_keyEntry 	; was in entry mode?
	GOTO	PROCESS_KEYS_END
	
	BCF	keypad_status, bit_keyEntry 
	
	; convert bcd+sign to binary in 2's complement
	MOVc	dro_offset_0, data_BCD0
	BCF	PCLATH, 3
	CALL	BCD2BIN
	BSF	PCLATH, 3
	
	; convert to mm if input was inches
	BTFSS	data_status, bit_statusUnit
	GOTO	PROCESS_KEYS_15_skipM2p54
	BCF	PCLATH, 3
	CALL	MULT_2p54
	BSF	PCLATH, 3
	
PROCESS_KEYS_15_skipM2p54:
	BTFSS	keypad_status, bit_keySign
	GOTO	PROCESS_KEYS_15_0
	NEGc	data_0
	
PROCESS_KEYS_15_0:
	BTFSC	keypad_status, bit_keyEntry0
	GOTO	PROCESS_KEYS_15_accept0
	BTFSC	keypad_status, bit_keyEntry1
	GOTO	PROCESS_KEYS_15_accept1
	BTFSC	keypad_status, bit_keyEntry2
	GOTO	PROCESS_KEYS_15_accept2
	
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_15_accept0:
	SUBc	data_0, dro0_0	
	MOVc	data_0, dro0_offset_0

	BCF	keypad_status, bit_keyEntry0
	GOTO	PROCESS_KEYS_END

PROCESS_KEYS_15_accept1:
	SUBc	data_0, dro1_0
	MOVc	data_0, dro1_offset_0
	
	BCF	keypad_status, bit_keyEntry1
	GOTO	PROCESS_KEYS_END
	
PROCESS_KEYS_15_accept2:
	SUBc	data_0, dro2_0
	MOVc	data_0, dro2_offset_0
	
	BCF	keypad_status, bit_keyEntry2
	GOTO	PROCESS_KEYS_END	
	
PROCESS_KEYS_END:
	CLRF	PCLATH
	RETURN



	
;#############################################################################
;	Delay routines	for 8MHz ; TODO update to 20MHz
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
	CLRF	PCLATH			
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


;#############################################################################
;	End of memory trap, should never be reached
;#############################################################################

	ORG	0x0FFB
	BSF	PORTB, 4
	BSF	PCLATH, 3
	STALL
	
;#############################################################################
;	EEPROM default for testing
;#############################################################################
	
	ORG	0x2100 ; the address of EEPROM is 0x2100 
; EEPROM data byte at 0x00 is config
; bit 0-3 x2 axis 0-3 (for radius to diameter direct reading)
; bit 4-7 is reverse axis direction
	DE	b'00010001'
; EEPROM data byte at 0x00 is config
; bit 0-3 x2 axis 0-3 (for radius to diameter direct reading)
; bit 4-7 is reverse axis direction

; EEPROM data byte at 0x01 is config_1
; display brightness, 0-7
	DE	4
	
;#############################################################################
;	End Declaration
;#############################################################################

	END

	
	
	
	
	
	
	
	
