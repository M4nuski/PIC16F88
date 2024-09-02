;#############################################################################
;
;	TM1637 7 segment interface (+ dot)
;	4 modules X 6 digits per module
;	
;#############################################################################

	LIST	p=16F88			; processor model
	ERRORLEVEL -302		; suppress "bank" warningsv                                                                                                                                  
#INCLUDE	<P16F88.INC>		; processor specific variable definitions
#INCLUDE	"PIC16F88_Macro.asm"

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
; pin 11 IOT PORTB5	I
; pin 12 IOA PORTB6	I ICSP PGC
; pin 13 IOA PORTB7	I ICSP PGD
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O Status ISR
; pin 16 I_X PORTA7	O 
; pin 17 IOA PORTA0	I ADC in
; pin 18 IOA PORTA1	I

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


#DEFINE	 Pin_ADC	PORTA, 0
;#DEFINE		PORTA, 1
#DEFINE Status_INIT	PORTA, 2
#DEFINE Status_MAIN	PORTA, 3

#DEFINE Status_LOOP	PORTA, 4
;MCLR			PORTA, 5
#DEFINE Status_ISR	PORTA, 6
;#DEFINE		PORTA, 7

;#DEFINE 		PORTB, 0
;#DEFINE 		PORTB, 1
;#DEFINE 		PORTB, 2
;#DEFINE 		PORTB, 3

;#DEFINE 		PORTB, 4
;#DEFINE 		PORTB, 5
;PGC			PORTB, 6
;PGD			PORTB, 7

; line output masks
#DEFINE ClockClear	b'11111110'
#DEFINE ClockSet	b'00000001'

#DEFINE Data0Clear	b'11111101'
#DEFINE Data0Set	b'00000010'

#DEFINE Data1Clear	b'11111011'
#DEFINE Data1Set	b'00000100'

#DEFINE Data2Clear	b'11110111'
#DEFINE Data2Set	b'00001000'

#DEFINE Data3Clear	b'11101111'
#DEFINE Data3Set	b'00010000'

; TM1637 commands:
#DEFINE _Data_Write		b'01000000'
#DEFINE _Data_Read		b'01000010'
#DEFINE _Data_Address_Auto	b'01000000'
#DEFINE _Data_Address_Fixed	b'01000100'
#DEFINE _Data_Mode_Normal	b'01000000'
#DEFINE _Data_Mode_Test	b'01001000'

#DEFINE _Address_C0H		b'11000000'
#DEFINE _Address_C1H		b'11000001'
#DEFINE _Address_C2H		b'11000010'
#DEFINE _Address_C3H		b'11000011'
#DEFINE _Address_C4H		b'11000100'
#DEFINE _Address_C5H		b'11000101'

#DEFINE _Display_01_16	b'10000000'
#DEFINE _Display_02_16	b'10000001'
#DEFINE _Display_04_16	b'10000010'
#DEFINE _Display_10_16	b'10000011'
#DEFINE _Display_11_16	b'10000100'
#DEFINE _Display_12_16	b'10000101'
#DEFINE _Display_13_16	b'10000110'
#DEFINE _Display_14_16	b'10000111'

#DEFINE _Display_OFF		b'10000000'
#DEFINE _Display_ON		b'10001000'

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

ResultL			EQU	0x23
ResultH			EQU	0x24

Current_Display	EQU	0x30
Current_Value		EQU	0x31
Current_Offset		EQU	0x32

Current_SetMask	EQU	0x33
Current_ClearMask	EQU	0x34

char_buffer		EQU	0x40
bit_count		EQU	0x41
PORTB_buffer		EQU	0x42

;#############################################################################
;	Macros
;#############################################################################
	
_W_1	MACRO ; x10 = 0.55 * 10us = 0.55us
	NOP
	ENDM
	
_W_2	MACRO ; x10 = 1.0 * 10us = 1.0us
	GOTO $ + 1
	ENDM
	
_W_3	MACRO ; x10 = 1.5 * 10us = 1.5us
	GOTO $ + 1
	NOP
	ENDM
	
_W_4	MACRO ; x10 = 2.1 * 10us = 2.1us
	GOTO $ + 1
	GOTO $ + 1
	ENDM
	
#DEFINE	RMW

	IFDEF	RMW
Pin_Clk_UP	MACRO
	MOVLW	ClockClear
	ANDWF	PORTB_buffer, F
	ENDM

Pin_Clk_DOWN	MACRO	
	MOVLW	ClockSet
	IORWF	PORTB_buffer, F
	ENDM
	
Pin_Data_UP	MACRO
	MOVF	Current_ClearMask, W
	ANDWF	PORTB_buffer, F
	ENDM	

Pin_Data_DOWN	MACRO
	MOVF	Current_SetMask, W
	IORWF	PORTB_buffer, F
	ENDM
	
Update_PORTB	MACRO
	MOVF	PORTB_buffer, W
	MOVWF	PORTB
	CALL 	WAIT_5us
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
	
SwitchData3	MACRO
	MOVLW	Data3Clear
	MOVWF	Current_ClearMask
	MOVLW	Data3Set
	MOVWF	Current_SetMask
	ENDM
	
	ELSE
	
Pin_Clk_UP	MACRO
	BCF	PORTB, 0
	ENDM

Pin_Clk_DOWN	MACRO	
	BSF	PORTB, 0
	ENDM
	
BIT	SET	1

Pin_Data_UP	MACRO
	BCF	PORTB, 2
	ENDM	

Pin_Data_DOWN	MACRO
	BSF	PORTB, 2
	ENDM
	
Update_PORTB	MACRO
	ENDM
	
SwitchData0	MACRO
BIT	SET	1
	ENDM
	
SwitchData1	MACRO
BIT	SET	2
	ENDM
	
SwitchData2	MACRO
BIT	SET	3
	ENDM
	
SwitchData3	MACRO
BIT	SET	4
	ENDM
	ENDIF
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
	
WAIT_OSC:
	BTFSS	OSCCON, IOFS
	GOTO	WAIT_OSC
	
	; init analog inputs
	CLRF	ANSEL		; all digital
	BSF	ANSEL, 0	; A0 analog input

	; init port directions
	CLRF	TRISA		; all outputs
	BSF	Pin_ADC		; A0 analog input
	CLRF	TRISB		; all outputs
	
	BSF	ADCON1, ADFM	;result right justified, 6 msb of ADRESH are 0
	BSF	ADCON1, VCFG0	;vref+ VCC
	BSF	ADCON1, VCFG1	;vref- GND
	BSF	ADCON1, ADCS2	;clock divider

	BANK0

	BSF	ADCON0, ADCS0	;fosc / 64
	BSF	ADCON0, ADCS1	;	
	BSF	ADCON0, ADON	;adc module ON	
	
	CLRF	PORTA
	CLRF	PORTB
	BSF	Status_INIT

;#############################################################################
;	Display Initialization
;#############################################################################
MAIN:
	BSF	Status_MAIN
	
	CLRF	PORTB
	CLRF	PORTB_buffer
	
	Pin_Clk_UP
	
	SwitchData0
	Pin_Data_UP
	SwitchData1
	Pin_Data_UP
	SwitchData2
	Pin_Data_UP
	SwitchData3
	Pin_Data_UP
	
	Update_PORTB
	
	CLRF	Current_Value
	CLRF	Current_Offset
	
;#############################################################################
;	Main Loop
;#############################################################################

LOOP:
	BSF	Status_LOOP
	
	;SwitchData0
	;CALL	SendDemo
	
	; INCF	Current_Offset, F
	; MOVF	Current_Offset, W
	; MOVWF	Current_Value
	; MOVLW	0x0F
	; ANDWF	Current_Value, F
	
	BSF	ADCON0, GO	; start conversion
LoopADC_Wait:
	BTFSC	ADCON0, GO	; pool GO/Done for 0
	GOTO	LoopADC_Wait
	
	BSF	STATUS, RP0 	;BANK1
	MOVF	ADRESL, W	
	BCF	STATUS, RP0 	;BANK0
	MOVWF	ResultL
	MOVF	ADRESH, W
	MOVWF	ResultH
	
	SwitchData1
	CALL	SendADC

	BCF	Status_LOOP
	
	CALL	WAIT_50ms
	CALL	WAIT_50ms
	CALL	WAIT_50ms
	CALL	WAIT_50ms
	CALL	WAIT_50ms
	GOTO	LOOP

	
;#############################################################################
;	End of main loop
;#############################################################################

	
	
;#############################################################################
;	Subroutines
;#############################################################################
SendDemo:
	CALL	TM1637_start
	
	MOVLW	_Data_Write
	MOVWF	char_buffer	
	CALL	TM1637_data
	
	CALL	TM1637_stop
	
	CALL	TM1637_start
	
	MOVLW	_Address_C3H
	MOVWF	char_buffer
	CALL	TM1637_data
	

	ARRAYf	table_hex, Current_Value
	MOVWF	char_buffer
	CALL	TM1637_data
	
	INCF	Current_Value, F
	MOVLW	0x0F
	ANDWF	Current_Value, F
	
	
	ARRAYf	table_hex, Current_Value
	MOVWF	char_buffer
	CALL	TM1637_data
	
	INCF	Current_Value, F
	MOVLW	0x0F
	ANDWF	Current_Value, F
	

	ARRAYf	table_hex, Current_Value
	MOVWF	char_buffer
	CALL	TM1637_data

	INCF	Current_Value, F
	MOVLW	0x0F
	ANDWF	Current_Value, F
	
	
	ARRAYf	table_hex, Current_Value
	MOVWF	char_buffer
	CALL	TM1637_data

	INCF	Current_Value, F
	MOVLW	0x0F
	ANDWF	Current_Value, F
	
	
	ARRAYf	table_hex, Current_Value
	MOVWF	char_buffer
	CALL	TM1637_data

	INCF	Current_Value, F
	MOVLW	0x0F
	ANDWF	Current_Value, F
	

	ARRAYf	table_hex, Current_Value
	MOVWF	char_buffer
	CALL	TM1637_data	
	
	INCF	Current_Value, F
	MOVLW	0x0F
	ANDWF	Current_Value, F
	
	
	CALL	TM1637_stop
	
	CALL	TM1637_start
	
	MOVLW	(_Display_ON | 4)
	MOVWF	char_buffer
	CALL	TM1637_data
	
	CALL	TM1637_stop
          
	RETURN

SendADC:
	CALL	TM1637_start
	
	MOVLW	_Data_Write
	MOVWF	char_buffer	
	CALL	TM1637_data
	
	CALL	TM1637_stop
	
	CALL	TM1637_start
	
	MOVLW	_Address_C3H
	MOVWF	char_buffer
	CALL	TM1637_data
	
	
	
	MOVLW	high (table_hex)
	MOVWF	PCLATH
	MOVLW	0x0F
	ANDWF	ResultL, W
	CALL	table_hex	
	MOVWF	char_buffer
	CALL	TM1637_data

	MOVLW	high (table_hex)
	MOVWF	PCLATH
	SWAPF	ResultL, F
	MOVLW	0x0F
	ANDWF	ResultL, W
	CALL	table_hex	
	MOVWF	char_buffer
	CALL	TM1637_data


	MOVLW	high (table_hex)
	MOVWF	PCLATH
	MOVLW	0x0F
	ANDWF	ResultH, W
	CALL	table_hex	
	MOVWF	char_buffer
	CALL	TM1637_data

	MOVLW	high (table_hex)
	MOVWF	PCLATH
	SWAPF	ResultH, F
	MOVLW	0x0F
	ANDWF	ResultH, W
	CALL	table_hex	
	MOVWF	char_buffer
	CALL	TM1637_data	
	
	
	CLRF	char_buffer
	CALL	TM1637_data

	CLRF	char_buffer
	CALL	TM1637_data
	
	
	CALL	TM1637_stop
	
	
	CALL	TM1637_start
	
	MOVLW	(_Display_ON | 4)
	MOVWF	char_buffer
	CALL	TM1637_data
	
	CALL	TM1637_stop
          
	RETURN
	
	

TM1637_start:
	Pin_Data_DOWN
	Update_PORTB
	RETURN

#DEFINE data_INLINE
	IFDEF data_INLINE
; inline version
TM1637_data:	; data is in file "char_buffer"

	Pin_Clk_DOWN
	Update_PORTB
	
	; BTFSS	char_buffer, 0
	; Pin_Data_DOWN
	; BTFSC	char_buffer, 0
	; Pin_Data_UP
	
	BTFSC	char_buffer, 0
	GOTO	TM1637_dataUP0
	MOVF	Current_SetMask, W
	IORWF	PORTB_buffer, F
	GOTO	TM1637_dataDone0
TM1637_dataUP0:
	MOVF	Current_ClearMask, W
	ANDWF	PORTB_buffer, F
TM1637_dataDone0:

	Pin_Clk_UP
	Update_PORTB
	Pin_Clk_DOWN
	Update_PORTB
	
	; BTFSS	char_buffer, 1
	; Pin_Data_DOWN
	; BTFSC	char_buffer, 1
	; Pin_Data_UP
	
	BTFSC	char_buffer, 1
	GOTO	TM1637_dataUP1
	MOVF	Current_SetMask, W
	IORWF	PORTB_buffer, F
	GOTO	TM1637_dataDone1
TM1637_dataUP1:
	MOVF	Current_ClearMask, W
	ANDWF	PORTB_buffer, F
TM1637_dataDone1:

	Pin_Clk_UP
	Update_PORTB
	Pin_Clk_DOWN
	Update_PORTB
	
	; BTFSS	char_buffer, 2
	; Pin_Data_DOWN
	; BTFSC	char_buffer, 2
	; Pin_Data_UP
	
	BTFSC	char_buffer, 2
	GOTO	TM1637_dataUP2
	MOVF	Current_SetMask, W
	IORWF	PORTB_buffer, F
	GOTO	TM1637_dataDone2
TM1637_dataUP2:
	MOVF	Current_ClearMask, W
	ANDWF	PORTB_buffer, F
TM1637_dataDone2:

	Pin_Clk_UP
	Update_PORTB
	Pin_Clk_DOWN
	Update_PORTB
	
	; BTFSS	char_buffer, 3
	; Pin_Data_DOWN
	; BTFSC	char_buffer, 3
	; Pin_Data_UP
	
	BTFSC	char_buffer, 3
	GOTO	TM1637_dataUP3
	MOVF	Current_SetMask, W
	IORWF	PORTB_buffer, F
	GOTO	TM1637_dataDone3
TM1637_dataUP3:
	MOVF	Current_ClearMask, W
	ANDWF	PORTB_buffer, F
TM1637_dataDone3:

	Pin_Clk_UP
	Update_PORTB
	Pin_Clk_DOWN
	Update_PORTB
		
	
	; BTFSS	char_buffer, 4
	; Pin_Data_DOWN
	; BTFSC	char_buffer, 4
	; Pin_Data_UP
	
	BTFSC	char_buffer, 4
	GOTO	TM1637_dataUP4
	MOVF	Current_SetMask, W
	IORWF	PORTB_buffer, F
	GOTO	TM1637_dataDone4
TM1637_dataUP4:
	MOVF	Current_ClearMask, W
	ANDWF	PORTB_buffer, F
TM1637_dataDone4:

	Pin_Clk_UP
	Update_PORTB
	Pin_Clk_DOWN
	Update_PORTB
	
	; BTFSS	char_buffer, 5
	; Pin_Data_DOWN
	; BTFSC	char_buffer, 5
	; Pin_Data_UP
	
	BTFSC	char_buffer, 5
	GOTO	TM1637_dataUP5
	MOVF	Current_SetMask, W
	IORWF	PORTB_buffer, F
	GOTO	TM1637_dataDone5
TM1637_dataUP5:
	MOVF	Current_ClearMask, W
	ANDWF	PORTB_buffer, F
TM1637_dataDone5:

	Pin_Clk_UP
	Update_PORTB
	Pin_Clk_DOWN
	Update_PORTB
		
	; BTFSS	char_buffer, 6
	; Pin_Data_DOWN
	; BTFSC	char_buffer, 6
	; Pin_Data_UP
	
	BTFSC	char_buffer, 6
	GOTO	TM1637_dataUP6
	MOVF	Current_SetMask, W
	IORWF	PORTB_buffer, F
	GOTO	TM1637_dataDone6
TM1637_dataUP6:
	MOVF	Current_ClearMask, W
	ANDWF	PORTB_buffer, F
TM1637_dataDone6:

	Pin_Clk_UP
	Update_PORTB
	Pin_Clk_DOWN
	Update_PORTB
		
	; BTFSS	char_buffer, 7
	; Pin_Data_DOWN
	; BTFSC	char_buffer, 7
	; Pin_Data_UP
	
	BTFSC	char_buffer, 7
	GOTO	TM1637_dataUP7
	MOVF	Current_SetMask, W
	IORWF	PORTB_buffer, F
	GOTO	TM1637_dataDone7
TM1637_dataUP7:
	MOVF	Current_ClearMask, W
	ANDWF	PORTB_buffer, F
TM1637_dataDone7:

	;last clock
	Pin_Clk_UP
	Update_PORTB	
	

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
	
	ENDIF

	IFDEF data_LOOP
;loop version
TM1637_data:	; data is in file "char_buffer";
	MOVLW	8
	MOVWF	bit_count
	
TM1637_dataLoop:
	Pin_Clk_DOWN
	Update_PORTB

	BTFSC	char_buffer, 0
	GOTO	TM1637_dataUP
	
	;;MOVF	Current_SetMask, W
	;;IORWF	PORTB_buffer, F
	Pin_Data_DOWN
	
	GOTO	TM1637_dataDone
TM1637_dataUP:

	;;MOVF	Current_ClearMask, W
	;;ANDWF	PORTB_buffer, F
	Pin_Data_UP
	
TM1637_dataDone:
	Pin_Clk_UP
	Update_PORTB
	
	RRF	char_buffer, F
	
	DECFSZ	bit_count, F
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
	ENDIF


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
;	PC 0x800 (1k) boundary
;#############################################################################

	;PC0x0800SKIP

;#############################################################################
;	Delay routines	for 8MHz
;#############################################################################

; at 8MHz intrc, 2Mips, 0.5us per instruction cycle
; 100, 249, 4: total is 100106 cycles, 50.053 ms
; 100, 199, 5: total is 100006 cycles, 50.003 ms

WAIT_50ms:				; (2) call
	MOVLW	100			; (1)
	MOVWF	WAIT_loopCounter1	; (1)
; 4
WAIT_50ms_loop1:			; 0.5ms / loop1
	MOVLW	199			; (1) 250 loops of 4 cycles (minus 2 loop for setup and next loop)
	MOVWF	WAIT_loopCounter2	; (1)
; 2 * WAIT_50ms_loop1 = 200
WAIT_50ms_loop2:			;  5 cycles per loop (2us / loop2)
	GOTO	$ + 1			; (2)	
	DECFSZ	WAIT_loopCounter2, F	; (1)
	GOTO	WAIT_50ms_loop2	; (2)
; 5 * WAIT_loopCounter2 = 995 * WAIT_loopCounter1 = 99500

	DECFSZ	WAIT_loopCounter1, F	; (1)
	GOTO	WAIT_50ms_loop1	; (2)
; 3 * WAIT_50ms_loop1 = 300
	RETURN				; (2)
; 2
; total = 100006

; total 10 cycles, 5us
WAIT_5us:				; (2) call is 2 cycle
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	RETURN				; (2) return is 2 cycle
	
; at 8MHz intrc, 2Mips, 0.5us per instruction cycle
; call and setup is 4 cycles
; 23 loops is 23 * 4 = 92 cycles
; 2xNOP and return is 4 cycles
; total 100 cycles = 50us

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
;	End Declaration
;#############################################################################

	END
