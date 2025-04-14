;#############################################################################
;
;	TM1637 7 segment interface (+ dot)
;	3 modules X 6 digits per module
;	Test for DRO Mill v0 simplification
;	
;#############################################################################

	LIST	p=16F88			; processor model
	ERRORLEVEL -302			; suppress "bank" warnings                                                                                                                                  
#INCLUDE	<P16F88.INC>		; processor specific variable definitions
#INCLUDE	"PIC16F88_Macro.asm"
#INCLUDE	"PIC16F88_Timing8MHz.asm"


;#############################################################################
;	Configuration
;#############################################################################

	__CONFIG	_CONFIG1, 	_CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & _WDT_OFF & _INTRC_IO
	__CONFIG	_CONFIG2, 	_IESO_OFF & _FCMEN_OFF

;#############################################################################
;	Pinout
;#############################################################################

; PIC16F88:
; pin  1 IOA PORTA2	O Status INIT
; pin  2 IOA PORTA3	O Status MAIN
; pin  3 IOA PORTA4	O Status LOOP
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O Clock
; pin  7 IO_ PORTB1	O Data0
; pin  8 IOR PORTB2	O Data1
; pin  9 IO_ PORTB3	O Data2

; pin 10 IO_ PORTB4	O Data3
; pin 11 IOT PORTB5	I Display 2 Data
; pin 12 IOA PORTB6	I Display 1 Data
; pin 13 IOA PORTB7	I Display 0 Data
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O Display Clock
; pin 16 I_X PORTA7	O 
; pin 17 IOA PORTA0	I 
; pin 18 IOA PORTA1	I

; TM1637 header:
;
; VCC
; GND
; DIO
; CLK
;
; "i2c" open collector protocol but no address and LSB first
; remove 2 SMT resistors on DIO and CLK to allow faster switching
;

#DEFINE	pin_STATUS	PORTA, 4
#DEFINE pin_DISP_CLOCK	PORTA, 6

#DEFINE pin_DISP2_DATA	PORTB, 5
#DEFINE Data2Clear	b'11011111'
#DEFINE Data2Set	b'00100000'
#DEFINE pin_DISP1_DATA	PORTB, 6
#DEFINE Data1Clear	b'10111111'
#DEFINE Data1Set	b'01000000'
#DEFINE pin_DISP0_DATA	PORTB, 7
#DEFINE Data0Clear	b'01111111'
#DEFINE Data0Set	b'10000000'


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
WAIT_loopCounter3	EQU	0x22


Current_Value		EQU	0x31
Current_Offset		EQU	0x32

Current_SetMask		EQU	0x33 ; TM1637 selected display data bit mask to set
Current_ClearMask	EQU	0x34 ; TM1637 selected display data bit mask to clear
disp_buffer		EQU	0x42 ; TM1637 data buffer
CFG_1			EQU	0x43 ; Configuration byte from EEPROM
loop_count		EQU	0x44 ; TM1637 data bit counter

;#############################################################################
;	Macros
;#############################################################################

Pin_Data_UP	MACRO
	MOVF	Current_SetMask, W
	IORWF	PORTB, F
	ENDM	

	
Pin_Data_DOWN	MACRO
	MOVF	Current_ClearMask, W
	ANDWF	PORTB, F
	ENDM

SwitchData0	MACRO
	MOVLW	Data0Clear
	MOVWF	Current_ClearMask
	MOVLW	Data0Set
	MOVWF	Current_SetMask
	ENDM
	
SwitchData1	MACRO
	MOVLW	Data1Clear
	MOVWF	Current_ClearMask
	MOVLW	Data1Set
	MOVWF	Current_SetMask
	ENDM
	
SwitchData2	MACRO
	MOVLW	Data2Clear
	MOVWF	Current_ClearMask
	MOVLW	Data2Set
	MOVWF	Current_SetMask
	ENDM

;#############################################################################
;	Reset Vector - Main Entry Point
;#############################################################################

	ORG	0x0000
	GOTO	SETUP

;#############################################################################
;	Interrupt Vector - Interrupt Service Routine
;#############################################################################

	ORG	0x0004
	RETFIE
	
;#############################################################################
;	Initial Setup
;#############################################################################

SETUP:

	; disable interrupts
	BCF	INTCON, GIE  ; global int
	
	CLRF	PORTA
	CLRF	PORTB
	
	BANK1
	
	; init osc 8MHz
	BCF	OSCCON, SCS0
	BCF	OSCCON, SCS1
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
	BTFSS	OSCCON, IOFS
	GOTO	$-1
	
	; init analog inputs
	CLRF	ANSEL		; all digital

	; init port directions
	CLRF	TRISA		; all outputs
	CLRF	TRISB		; all outputs
	
	BANK0	

	CLRF	PORTA
	CLRF	PORTB
	
	;BSF	Status_INIT

;#############################################################################
;	Display Initialization
;#############################################################################
MAIN:
	;BSF	Status_MAIN
	
	CLRF	PORTB
	
	BSF	pin_DISP_CLOCK
	BSF	pin_DISP0_DATA
	BSF	pin_DISP1_DATA
	BSF	pin_DISP2_DATA
	
	MOVLW	b'00000010'
	MOVWF	CFG_1
	
	CLRF	Current_Value
	CLRF	Current_Offset
	
;#############################################################################
;	Main Loop
;#############################################################################

LOOP:
	BSF	PIN_STATUS
	SwitchData0
	CALL	SendDemo
	
	BCF	PIN_STATUS
	SwitchData1
	CALL	SendDemo
	
	BSF	PIN_STATUS
	SwitchData2
	CALL	SendDemo
	
	BCF	PIN_STATUS
	SwitchData0
	CALL	SendDemo
	
	BSF	PIN_STATUS
	SwitchData1
	CALL	SendDemo
	
	BCF	PIN_STATUS
	SwitchData2
	CALL	SendDemo

	; inline with skippable macro: 6.5 x 2ms for updating 4 displays, 426 words of program memory
	; inline with inline bitset:6.2 x 2ms for updating 4 displays, 402 words of program memory
	; loop with skippable macro: 6.8 x 2ms for updating 4 displays, 291 words of program memory, 1 byte of ram
	; loop with inline bitset: 6.5 x 2ms for updating 4 displays, 288 words of program memory, 1 byte of ram
	
	; straight: 2ms per display, 3 bytes of RAM
	
	INCF	Current_Offset, F
	MOVF	Current_Offset, W
	MOVWF	Current_Value
	MOVLW	0x0F
	ANDWF	Current_Value, F

	; CALL	WAIT_50ms
	; CALL	WAIT_50ms
	; CALL	WAIT_50ms
	; CALL	WAIT_50ms
	; CALL	WAIT_50ms
	
	


	GOTO	LOOP

	
;#############################################################################
;	End of main loop
;#############################################################################

	
	
	
;#############################################################################
; TM1637 6digits x 7segments displays
;#############################################################################
TM1637_PREFACE:

	Pin_Data_DOWN
	inline_5us
	
	MOVF	CFG_1, W
	IORLW	_Data_Write
	CALL	TM1637_data
	
	Pin_Data_DOWN
	inline_5us
	BSF	pin_DISP_CLOCK
	inline_5us
	Pin_Data_UP
	inline_5us;inline_50us
	
	Pin_Data_DOWN
	inline_5us
	
	MOVLW	_Address_C3H
	CALL	TM1637_data
	RETURN
	
;loop version
TM1637_data:	; data is in W;
	MOVWF	disp_buffer
	MOVLW	8
	MOVWF	loop_count
	
TM1637_dataLoop:
	BCF	pin_DISP_CLOCK
	inline_5us

	BTFSC	disp_buffer, 0
	GOTO	TM1637_dataUP
	Pin_Data_DOWN
	GOTO	TM1637_dataDone
TM1637_dataUP:
	Pin_Data_UP
	
TM1637_dataDone:
	inline_5us
	BSF	pin_DISP_CLOCK
	inline_5us
	
	RRF	disp_buffer, F
	DECFSZ	loop_count, F
	GOTO	TM1637_dataLoop

	;ACK
	BCF	pin_DISP_CLOCK
	Pin_Data_UP
	inline_5us	

	BSF	pin_DISP_CLOCK
	inline_5us

	BCF	pin_DISP_CLOCK
	Pin_Data_DOWN
	inline_5us
	RETURN

TM1637_ANNEX:
	Pin_Data_DOWN
	inline_5us
	BSF	pin_DISP_CLOCK
	inline_5us
	Pin_Data_UP
	inline_5us;inline_50us
	
	Pin_Data_DOWN
	inline_5us
	
	MOVF	CFG_1, W
	IORLW	_Display_ON
	CALL	TM1637_data
	
	Pin_Data_DOWN
	inline_5us
	BSF	pin_DISP_CLOCK
	inline_5us
	Pin_Data_UP
	inline_5us;inline_50us
	
	RETURN
	
;#############################################################################
;	Subroutines
;#############################################################################
SendDemo:
	CALL	TM1637_PREFACE

	ARRAYf	table_hex, Current_Value
	CALL	TM1637_data
	
	INCF	Current_Value, F
	MOVLW	0x0F
	ANDWF	Current_Value, F
	
	
	ARRAYf	table_hex, Current_Value
	CALL	TM1637_data
	
	INCF	Current_Value, F
	MOVLW	0x0F
	ANDWF	Current_Value, F
	

	ARRAYf	table_hex, Current_Value
	CALL	TM1637_data

	INCF	Current_Value, F
	MOVLW	0x0F
	ANDWF	Current_Value, F
	
	
	ARRAYf	table_hex, Current_Value
	CALL	TM1637_data

	INCF	Current_Value, F
	MOVLW	0x0F
	ANDWF	Current_Value, F
	
	
	ARRAYf	table_hex, Current_Value
	CALL	TM1637_data

	INCF	Current_Value, F
	MOVLW	0x0F
	ANDWF	Current_Value, F
	

	ARRAYf	table_hex, Current_Value
	CALL	TM1637_data	
	
	INCF	Current_Value, F
	MOVLW	0x0F
	ANDWF	Current_Value, F
	
	
	CALL	TM1637_ANNEX
          
	RETURN


;#############################################################################
;	Tables
;#############################################################################

	PC0x0100SKIP; align to next 256 byte boundary in program memory

; 	Int to Hex nibble char table
table_hex:
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
;	PC 0x800 (1k) boundary
;#############################################################################

	;PC0x0800SKIP


;#############################################################################
;	End Declaration
;#############################################################################

	END
