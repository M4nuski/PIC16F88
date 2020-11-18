;#############################################################################
;	Nixie GPS 3
;	GPS Time: read, parse, adjust timezone, display
;	GPS Alt: parse and convert M/Ft
;	GPS Lat/Long: parse and convert minutes.fractions to fraction
;#############################################################################

	LIST	p=16F88			; processor model
#INCLUDE	<P16F88.INC>		; processor specific variable definitions
#INCLUDE	<PIC16F88_Macro.asm>	; base macro for banks, context, branchs
#INCLUDE	<PIC16F88_MacroExt.asm> ; 16/24/32 bit instructions extensions

;#############################################################################
;	Configuration	
;#############################################################################

	__CONFIG	_CONFIG1, 	_CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & _WDT_OFF & _INTRC_IO					
	__CONFIG	_CONFIG2, 	_IESO_OFF & _FCMEN_OFF

;#############################################################################
;	Pinout
;#############################################################################

; PIC16F88:
; pin  1 IOA PORTA2	O NixieSerial - Latch
; pin  2 IOA PORTA3	I AU_select 0=M 1=Ft
; pin  3 IOA PORTA4	I TZ_select 0=-5 (EST) 1=-4 (EDT)
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O Step1_red
; pin  7 IO_ PORTB1	O Step2_yellow
; pin  8 IOR PORTB2	I RX from GPS
; pin  9 IO_ PORTB3	I Mode Select bit 0

; pin 10 IO_ PORTB4	I Mode Select bit 1
; pin 11 IOT PORTB5	O TX to computer
; pin 12 IOA PORTB6	I ICSP PGC
; pin 13 IOA PORTB7	I ICSP PGD
; pin 14 PWR VDD	VCC
; pin 15 _O_ PORTA6	(XT 18.432MHz, wait_1s at 23) Step3_green
; pin 16 I__ PORTA7	(XT Low BRGH, @29 for 9600)
; pin 17 IOA PORTA0	O NixieSerial - Clock
; pin 18 IOA PORTA1	O NixieSerial - Data

; Nixie Serial to Parallel module:
; (Parallel out side)
; Data
; Ground
; Latch
; Clock
; VCC

#DEFINE NixieSerial_Clock	PORTA, 0
#DEFINE NixieSerial_Data	PORTA, 1
#DEFINE NixieSerial_Latch	PORTA, 2

#DEFINE AU_Select		PORTA, 3
#DEFINE TZ_Select		PORTA, 4

#DEFINE Step3_green		PORTA, 6

#DEFINE Step1_red 		PORTB, 0
#DEFINE Step2_yellow		PORTB, 1

#DEFINE Mode_Select_b0	PORTB, 3
#DEFINE Mode_Select_b1	PORTB, 4

#DEFINE	END_MARKER		0xFF
#DEFINE	CONV_DOT		'.' - '0'
#DEFINE	CONV_MINUS		'-' - '0'

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

Serial_Data		EQU	0x23
Serial_Status		EQU	0x24

_Serial_bit_RX_frameError 		EQU	0	;uart module frame error
_Serial_bit_RX_overrunError 		EQU	1	;uart module overrun error
_Serial_bit_RX_bufferOverrun 		EQU	2	;RX circular buffer overrun error
_Serial_bit_RX_inhibit		EQU	3	;discard RX data

data_unit		EQU	0x25 ; M F N S E W
TZ_offset		EQU	0x27 ; for TZ adjust
WriteLoop		EQU	0x28 ; for NixieSerial and WriteString
TX_Temp			EQU	0x29 ; for RX/TX buffer address calculation

data_buffer		EQU	0x2A ; 0x2A to 0x3E -> 20 bytes

; alias for static buffer positions
; 235959
data_H10			EQU	0x2A
data_H01			EQU	0x2B
data_m10			EQU	0x2C
data_m01			EQU	0x2D
data_s10			EQU	0x2E
data_s01			EQU	0x2F

; 4538.10504,N
data_latD10			EQU	0x2A
data_latD01			EQU	0x2B
data_latM10			EQU	0x2C
data_latM01			EQU	0x2D
data_latDot			EQU	0x2E
data_latFract			EQU	0x2F

; 07318.08944,W
data_longD100			EQU	0x2A
data_longD010			EQU	0x2B
data_longD001			EQU	0x2C
data_longM10			EQU	0x2D
data_longM01			EQU	0x2E
data_longDot			EQU	0x2F
data_longFract			EQU	0x30

;			EQU	0x3A
;			EQU	0x3B
;			EQU	0x3C
;			EQU	0x3D 
;			EQU	0x3E ; last byte of data_buffer
BCD_Result		EQU	0x3F ; 0x40 0x41 0x42 for 8 bcd nibbles, up to 16 77 72 15 (24 bit to bcd)
D88_Fract		EQU	0x43 ; 0x44 0x45 resulting fraction of div
D88_Modulo		EQU	0x46 ; 0x47 0x48 Modulo for preset div, also index for arbitrary div
D88_Num			EQU	0x49 ; 0x4A 0x4B 0x4C numerator for div and receive modulo (remainder)
D88_Denum		EQU	0x4D ; 0x4E 0x4F 0x50 denumerator for div
Display_Mode		EQU	0x51 
_mode_Time				EQU	0
_mode_Alt				EQU	1
_mode_Lat				EQU	2
_mode_Long				EQU	3

IntToConvert		EQU	0x52 ; 0x53 0x54 0x55 for convert to hex or BCD
;			EQU	0x56
;			EQU	0x57
;			EQU	0x58
NixieVarX		EQU	0x59 ; inner data
NixieVarY		EQU	0x5A ; inner data
NixieLoop		EQU	0x5B ; inner data
NixieSeg		EQU	0x5C ; to pass data between routines
NixieData		EQU	0x5D ; to pass data between routines
NixieTube		EQU	0x5E ; to pass data between routines
NixieDemoCount		EQU	0x5F ; global for demo

;			EQU	0x60
;			EQU	0x61
;			EQU	0x62
;			EQU	0x63
;			EQU	0x64
;			EQU	0x65
;			EQU	0x66
;			EQU	0x67
;			EQU	0x68
;			EQU	0x69
;			EQU	0x6A
;			EQU	0x6B
;			EQU	0x6C

; GPR files in GPR for context saving
;STACK_FSR		EQU	0x6D
;STACK_SCRATCH		EQU	0x6E
;STACK_PCLATH		EQU	0x6F

; Bank 1

_Serial_RX_buffer_startAddress	EQU	0xA0 ; circular RX buffer start
_Serial_RX_buffer_endAddress		EQU	0xC0 ; circular RX buffer end

_Serial_TX_buffer_startAddress	EQU	0xC0 ; circular TX buffer start
_Serial_TX_buffer_endAddress		EQU	0xE0 ; circular TX buffer end

NixieBuffer		EQU	0xE0 ; to 0xE9, 10 bytes, 80 bit

;#############################################################################
;	Shared Files 0x70 - 0x7F / 0xF0 - 0xFF
;#############################################################################

Serial_RX_buffer_rp	EQU	0x70 ; circular RX buffer read pointer
Serial_RX_buffer_wp	EQU	0x71 ; circular RX buffer write pointer

Serial_TX_buffer_rp	EQU	0x72 ; circular TX buffer read pointer
Serial_TX_buffer_wp	EQU	0x73 ; circular TX buffer write pointer

;			EQU	0x74
;			EQU	0x75
;			EQU	0x76
;			EQU	0x77
;			EQU	0x78
;			EQU	0x79
;			EQU	0x7A
;			EQU	0x7B
;			EQU	0x7C

; GPR files in shared GPR for instruction extensions
;SCRATCH		EQU	0x7D

; GPR files in shared GPR for context saving
;STACK_STATUS		EQU	0x7E
;STACK_W		EQU	0x7F

_char_dot	EQU 10
_char_column	EQU 11
_char_minus	EQU 12
_char_plus	EQU 13
_char_E		EQU 14
_char_C		EQU 15
_char_F		EQU 16
_char_M		EQU 17
_char_topdot	EQU 18
_char_comma	EQU 19
_char_A		EQU 20
_char_T		EQU 21

_index_Alt	EQU 8
_index_Lat	EQU 1
_index_Long	EQU 3

;#############################################################################
;	MACRO
;#############################################################################
	
WRITESTRING_LN	MACRO string
	;ORG	( $ & 0xFFFFFF00 ) + 0x100
	LOCAL	_END, _TABLE, _NEXT
	MOVLW	high (_TABLE)
	MOVWF	PCLATH
	CLRF	WriteLoop
_NEXT
	MOVF	WriteLoop, W
	CALL 	_TABLE
	ANDLW	0xFF
	BTFSC	STATUS, Z
	GOTO	_END
	MOVWF	Serial_Data
	CALL	Serial_TX_write
	INCF	WriteLoop, F
	GOTO	_NEXT
_TABLE:
	ADDWF	PCL, F
	DT	string, 13, 10, 0
_END:
	ENDM
	
WRITE_NIXIE_L	MACRO Tube, Data
	MOVLW	Tube
	MOVWF	NixieTube
	MOVLW 	Data
	MOVWF	NixieData
	CALL	Nixie_DrawNum	
	ENDM
	
WRITE_NIXIE_F	MACRO Tube, Data
	MOVLW	Tube
	MOVWF	NixieTube
	MOVF 	Data, W
	MOVWF	NixieData
	CALL	Nixie_DrawNum
	ENDM
	
WRITE_NIXIE_W	MACRO Tube
	MOVWF	NixieData
	MOVLW	Tube
	MOVWF	NixieTube
	CALL	Nixie_DrawNum	
	ENDM
	
WRITE_SERIAL_L	MACRO lit
	MOVLW	lit
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	ENDM
	
WRITE_SERIAL_F	MACRO file
	LOCAL	_invalidASCII, _end	
	MOVF	file, W
	MOVWF	Serial_Data
	CMP_lf	' ', Serial_Data
	BR_GT	_invalidASCII	; invalid if ' ' > data
	CMP_lf	126, Serial_Data
	BR_LT	_invalidASCII	; invalid if 126 < data
	GOTO	_end
_invalidASCII:
	STR	'?', Serial_Data
_end:
	CALL 	Serial_TX_write
	ENDM
	
WRITE_SERIAL_FITOA	MACRO file
	MOVF	file, W
	MOVWF	Serial_Data
	CALL 	Serial_TX_write_ITOA
	ENDM
	
WRITE_SERIAL_W	MACRO
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
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
	PUSH
	PUSHfsr
	
	BSF	Step1_red
	
	BTFBS	PIR1, RCIF, ISR_RX	; check if RX interrupt
	BTFBS	PIR1, TXIF, ISR_TX	; check if TX interrupt
	
	GOTO	ISR_END 		; unkown interrupt
	
ISR_RX:
	BTFSC	RCSTA, FERR		; check for framing error
	BSF	Serial_Status, _Serial_bit_RX_frameError
	
ISR_RX1:
	WRITEp	RCREG, Serial_RX_buffer_wp
	
	BTFSC	Serial_Status, _Serial_bit_RX_inhibit	
	GOTO	ISR_RX3
	
	INCF	Serial_RX_buffer_wp, F	; writePtr++	
	CMP_lf	_Serial_RX_buffer_endAddress, Serial_RX_buffer_wp ; warp around
	BR_NE	ISR_RX2	
	STR	_Serial_RX_buffer_startAddress, Serial_RX_buffer_wp

ISR_RX2:
	CMP_ff	Serial_RX_buffer_wp, Serial_RX_buffer_rp ; check for circular buffer overrun
	SK_NE		; skip if both buffer are not equal after moving the write pointer forward
	BSF	Serial_Status, _Serial_bit_RX_bufferOverrun
	
ISR_RX3:
	BTFBS	PIR1, RCIF, ISR_RX1		; loop back if interrupt flag is still set	
	BTFBC	RCSTA, OERR, ISR_RX_END	; check for register overrun error
	BSF	Serial_Status, _Serial_bit_RX_overrunError
	BCF	RCSTA, CREN		; reset rx
	MOVF	RCREG, W		; purge receive register
	MOVF	RCREG, W
	BSF	RCSTA, CREN	
	
ISR_RX_END:
	BTFBC	PIR1, TXIF, ISR_END		; check if there's also a TX interrupt

ISR_TX:
	;BSF	ISR_TX_yellow
	CMP_ff	Serial_TX_buffer_rp, Serial_TX_buffer_wp	; check for data to send
	BR_EQ	ISR_TX_empty
	
	READp	Serial_TX_buffer_rp, TXREG		; indirect read buffer and store in ausart register

	INCF	Serial_TX_buffer_rp, F		; move pointer forward
	CMP_lf	_Serial_TX_buffer_endAddress, Serial_TX_buffer_rp
	BR_NE	ISR_END					; warp around if at the end
	STR	_Serial_TX_buffer_startAddress, Serial_TX_buffer_rp
	GOTO	ISR_END
	
ISR_TX_empty:
	BANK0_1
	BCF	PIE1, TXIE	; disable tx interrupts	
	BANK1_0


ISR_END:
	BCF	Step1_red
		
	POPfsr
	POP
	RETFIE
	
;#############################################################################
;	Initial Setup
;#############################################################################

SETUP:

	BANK1
	
	; init port directions 
	CLRF	TRISA		; all outputs	
	BSF	AU_Select	; Bit3 is input
	BSF	TZ_Select	; Bit4 is input
	
	CLRF	TRISB		; all outputs	
	BSF	TRISB, 2	; Bit2 is input (RX)
	BSF	Mode_Select_b0	; Bit3 is input
	BSF	Mode_Select_b1	; Bit4 is input
	
	; init analog inputs
	CLRF	ANSEL		; all digital
	
	; init osc 8MHz
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
	; init AUSART transmitter
	;BSF	TXSTA, CSRC	; not used in async - set as clock source master
	BCF 	TXSTA, TX9	; 8 bit tx
	BSF	TXSTA, TXEN	; enable tx
	BCF	TXSTA, SYNC	; async
	
	; set 9600 baud rate for 8MHz clock
	BSF 	TXSTA, BRGH	; high speed baud rate generator	
	MOVLW	51		; 9600 bauds
	MOVWF	SPBRG
	
	BSF	PIE1, RCIE	; enable rx interrupts
	BCF	PIE1, TXIE	; disable tx interrupts
	
	BANK0
	
	; init AUSART receiver
	BSF	RCSTA, SPEN	; serial port enabled
	BCF	RCSTA, RX9	; 8 bit rx
	;BSF	RCSTA, SREN	; not used in async - enable single receive
	BSF	RCSTA, CREN	; enable continuous receive
	BCF	RCSTA, ADDEN	; disable addressing
	
	; initialize circular buffer pointers
	MOVLW	_Serial_RX_buffer_startAddress
	MOVWF	Serial_RX_buffer_rp
	MOVWF	Serial_RX_buffer_wp
	
	MOVLW	_Serial_TX_buffer_startAddress
	MOVWF	Serial_TX_buffer_rp
	MOVWF	Serial_TX_buffer_wp

	CLRF	PORTA
	CLRF	PORTB
	CLRF	NixieDemoCount
	CLRF	Serial_Status
	BSF	Serial_Status, _Serial_bit_RX_inhibit
	
	STR	_mode_Time, Display_Mode
	
;welcome message

	CALL	Nixie_All
	CALL	Nixie_Send
	FAR_CALL	WAIT_1s	
	
	CALL	Nixie_None
	CALL	Nixie_Send
	FAR_CALL	WAIT_1s	
	
	CALL	Nixie_None
	WRITE_NIXIE_L	2, _char_E
	WRITE_NIXIE_L	3, _char_C
	WRITE_NIXIE_L	5, 2
	WRITE_NIXIE_L	6, 0
	WRITE_NIXIE_L	7, 2
	WRITE_NIXIE_L	8, 0
	CALL	Nixie_Send
	FAR_CALL	WAIT_1s	
	
; enable interrupts
	BSF	INTCON, PEIE ; peripheral int
	BSF	INTCON, GIE  ; global int	
	
	
	PC0x0100ALIGN		startUpMessage
	WRITESTRING_LN		"Nixie 3 - Time + Alt + Lat + Long"



;#############################################################################
;	Main Loop	
;#############################################################################


	
LOOP:
	CALL	Nixie_None	
	
	CLRF	Display_Mode
	BTFSC	Mode_Select_b0
	BSF	Display_Mode, 0
	BTFSC	Mode_Select_b1
	BSF	Display_Mode, 1

	CMP_lf	_mode_Time, Display_Mode
	BR_EQ	MAIN_TIME

	CMP_lf	_mode_Alt, Display_Mode
	BR_EQ	MAIN_ALT

	CMP_lf	_mode_Lat, Display_Mode
	BR_EQ	MAIN_LAT

	CMP_lf	_mode_Long, Display_Mode
	BR_EQ	MAIN_LONG

	WRITE_SERIAL_L	'?'
	FAR_CALL	Wait_1s

	GOTO	LOOP



;#############################################################################
;	Time display 
;#############################################################################

MAIN_TIME:
	WRITE_NIXIE_L	4, _char_column

	CALL	READ_NEXT_TIME
	BW_False	Draw_No_time

	; Adjust time zone
	MOVLW	5
	BTFSC	TZ_Select
	MOVLW	4
	MOVWF	TZ_offset
	CALL	ADJUST_TZ

	; Draw time data on nixie tubes
	WRITE_NIXIE_F	2, data_H10
	WRITE_NIXIE_F	3, data_H01
	
	WRITE_NIXIE_L	4, _char_column
	
	WRITE_NIXIE_F	5, data_m10
	WRITE_NIXIE_F	6, data_m01
	
	WRITE_NIXIE_F	8, data_s10
	WRITE_NIXIE_F	9, data_s01

	; Send time data to serial
	WRITE_SERIAL_FITOA	data_H10
	WRITE_SERIAL_FITOA	data_H01
	WRITE_SERIAL_L	':'
	WRITE_SERIAL_FITOA	data_m10
	WRITE_SERIAL_FITOA	data_m01
	WRITE_SERIAL_L	':'
	WRITE_SERIAL_FITOA	data_s10
	WRITE_SERIAL_FITOA	data_s01
	WRITE_SERIAL_L	'E'
	MOVLW	'S'
	BTFSC	TZ_select
	MOVLW	'D'
	WRITE_SERIAL_W	
	WRITE_SERIAL_L	'T'

	GOTO	ErrorCheck1

Draw_No_time:
	CALL	WAIT_DATA

	WRITE_SERIAL_L	'N'
	WRITE_SERIAL_L	'T'

	GOTO	ErrorCheck1



;#############################################################################
;	Altitude display 
;#############################################################################

MAIN_ALT:
	WRITE_NIXIE_L	4, _char_column
	WRITE_NIXIE_L	1, _char_A
	
	MOVLW	_index_Alt
	CALL	READ_NEXT		; wait and read CSV data at index 8
	BW_False	Draw_No_alt

	WRITE_SERIAL_FITOA	data_buffer
	WRITE_SERIAL_FITOA	data_buffer + 1
	WRITE_SERIAL_FITOA	data_buffer + 2
	WRITE_SERIAL_FITOA	data_buffer + 3
	WRITE_SERIAL_FITOA	data_buffer + 4
	WRITE_SERIAL_FITOA	data_buffer + 5
	WRITE_SERIAL_FITOA	data_buffer + 6
	WRITE_SERIAL_FITOA	data_buffer + 7
	WRITE_SERIAL_FITOA	data_buffer + 8
	WRITE_SERIAL_FITOA	data_buffer + 9
	WRITE_SERIAL_L		' '
	WRITE_SERIAL_F		data_unit
	WRITE_SERIAL_L		' '

	CMP_lf	'M', data_unit
	BR_EQ	MAIN_ALT_Meter
	CMP_lf	'F', data_unit
	BR_EQ	MAIN_ALT_Feet	
	GOTO	MAIN_ALT_draw

MAIN_ALT_Meter:			; received unit is Meter
	BTFSS	AU_Select
	GOTO	MAIN_ALT_Meter_format	; if requested unit is meter check range and draw
	
	WRITE_SERIAL_L		'>'
	WRITE_SERIAL_L		'F'
	WRITE_SERIAL_L		' '
	; else convert to feet
	; 3.281ft / m
	; F = M * 33 / 10 (good enough...)	
	
	CALL	Conv_Str_to_Int	; convert data_buffer string to int in D88_Denum
	
	WRITE_SERIAL_L	'i'
	MOVc	D88_Denum, IntToConvert
	CALL	WriteHexShort	
	
	FAR_CALL	MULT33s ; D88_Num = D88_Denum * 33
	
	WRITE_SERIAL_L	'x'
	MOVc	D88_Num, IntToConvert
	CALL	WriteHexColor
	
	CALL	ColorToBCD
	CALL	ExpandBCD_trimLeft
	WRITE_SERIAL_L	'B'
	MOVi	BCD_Result, IntToConvert
	CALL	WriteHexInteger
	
	;call feet format routine
	GOTO	MAIN_ALT_Feet_format
	
	
MAIN_ALT_Meter_format:
	WRITE_NIXIE_L	3, _char_M
	
	CMP_lf	CONV_MINUS, data_buffer	; check if negative
	BR_NE	MAIN_ALT_Meter_format_pos
	
	CMP_lf	CONV_DOT, data_buffer + 1	; impossible dot at buffer[1] "-.0000F"
	BR_EQ	MAIN_ALT_draw
	CMP_lf	CONV_DOT, data_buffer + 2	; dot at buffer[2] "-0.000F"
	BR_EQ	MAIN_ALT_draw
	CMP_lf	CONV_DOT, data_buffer + 3	; dot at buffer[3] "-00.00F"
	BR_EQ	MAIN_ALT_draw	
	CMP_lf	CONV_DOT, data_buffer + 4 	; dot at buffer[4] "-000.0F"
	BR_EQ	MAIN_ALT_draw
	
	STR	data_buffer + 4, FSR	; buffer[4]
	GOTO	MAIN_ALT_Meter_format_2
	
MAIN_ALT_Meter_format_pos:
	CMP_lf	CONV_DOT, data_buffer		; impossible dot at buffer[0] ".0000F"
	BR_EQ	MAIN_ALT_draw
	CMP_lf	CONV_DOT, data_buffer + 1	; dot at buffer[1] "0.000F"
	BR_EQ	MAIN_ALT_draw
	CMP_lf	CONV_DOT, data_buffer + 2	; dot at buffer[2] "00.00F"
	BR_EQ	MAIN_ALT_draw	
	CMP_lf	CONV_DOT, data_buffer + 3	; dot at buffer[3] "000.0F"
	BR_EQ	MAIN_ALT_draw
	
	; ALT > 999.9 remove decimal
	
	STR	data_buffer + 3, FSR	; buffer[3]
	
MAIN_ALT_Meter_format_2:
	INCF	FSR, F
	CMP_lf	END_MARKER, INDF
	BR_EQ	Draw_No_alt
	CMP_lf	CONV_DOT, INDF
	BR_NE	MAIN_ALT_Meter_format_2
	
	STR	END_MARKER, INDF	;replace dot with end_marker
	GOTO	MAIN_ALT_draw



MAIN_ALT_Feet:		; received unit is Feet
	BTFSC	AU_Select	; if requested unit is feet draw
	GOTO	MAIN_ALT_Feet_format
	;convert to meter
	;*100
	;/33
	WRITE_SERIAL_L		'>'
	WRITE_SERIAL_L		'M'
	WRITE_SERIAL_L		' '
	
	CALL	Conv_Str_to_Int	; convert data_buffer string to int in D88_Denum
	
	WRITE_SERIAL_L	'i'
	MOVc	D88_Denum, IntToConvert
	CALL	WriteHexShort	

	FAR_CALL	MULT100s	; D88_Num = D88_Denum * 100
		
	WRITE_SERIAL_L	'x'
	MOVc	D88_Num, IntToConvert
	CALL	WriteHexColor
	
	FAR_CALL	DIV33c		; D88_Fract = D88_Num / 33, D88_Num = D88_Num % 33
	WRITE_SERIAL_L	'/'
	MOVc	D88_Fract, IntToConvert
	CALL	WriteHexColor
	
	CALL	ColorToBCD
	WRITE_SERIAL_L	'B'
	MOVi	BCD_Result, IntToConvert
	CALL	WriteHexInteger
	
	;call meter format routine
	GOTO	MAIN_ALT_Meter_format
	
	
MAIN_ALT_Feet_format:
	WRITE_NIXIE_L	3, _char_F
	
	STR	data_buffer - 1, FSR	; buffer[-1]
	
MAIN_ALT_Feet_format2:
	INCF	FSR, F
	CMP_lf	END_MARKER, INDF
	BR_EQ	Draw_No_alt
	CMP_lf	CONV_DOT, INDF
	BR_NE	MAIN_ALT_Feet_format2
	
	STR	END_MARKER, INDF	;replace dot with end_marker
	GOTO	MAIN_ALT_draw




MAIN_ALT_draw:
	STR	9, NixieTube
	
	MOVLW	data_buffer
	MOVWF	FSR
MAIN_ALT_1:				; seek end of buffer
	CMP_lf	END_MARKER, INDF
	BR_EQ	MAIN_ALT_2
	INCF	FSR, F
	GOTO	MAIN_ALT_1

MAIN_ALT_2:
	DECF	FSR, F

	MOV	INDF, NixieData	; load char

	CMP_lf	CONV_DOT, NixieData	; convert special char ','
	BR_NE	MAIN_ALT_3a
	STR	_char_comma, NixieData
MAIN_ALT_3a:
	CMP_lf	CONV_MINUS, NixieData	; convert special char '-'
	BR_NE	MAIN_ALT_3b
	STR	_char_minus, NixieData
	STR	4, NixieTube
	CALL	Nixie_ClearTube ;remove ":" and replace by '-'
	STR	data_buffer, FSR; short circuit out of loop when encountering a '-'
MAIN_ALT_3b:
	MOV	FSR, TZ_offset	;push FSR
	CALL	Nixie_DrawNum
	MOV	TZ_offset, FSR	;pop FSR
	
	DECF	NixieTube, F
	CMP_lf	data_buffer, FSR
	BR_EQ	ErrorCheck1
	GOTO	MAIN_ALT_2
	
Draw_No_alt:
	CALL 	WAIT_DATA
	
	WRITE_SERIAL_L	'N'
	WRITE_SERIAL_L	'A'
	
	GOTO	ErrorCheck1



;#############################################################################
;	Latitude display 
;#############################################################################

MAIN_LAT:
	MOVLW	_index_Lat
	CALL	READ_NEXT		; wait and read CSV data at index 3
	BW_False	Draw_No_Lat
	
	WRITE_SERIAL_F		data_unit
	WRITE_SERIAL_L		' '
	
	; direction
	CMP_lf	'N', data_unit
	BR_EQ	MAIN_LAT_1N
	CMP_lf	'S', data_unit
	BR_EQ	MAIN_LAT_1S
	GOTO	MAIN_LAT_2	
MAIN_LAT_1N:
	WRITE_NIXIE_L	0, _char_plus
	GOTO	MAIN_LAT_2
MAIN_LAT_1S:
	WRITE_NIXIE_L	0, _char_minus
MAIN_LAT_2:
	; ,4538.12345,N,
	;degrees
	; dont draw if 0
	CMP_lf	0, data_latD10
	BR_EQ	MAIN_LAT_2a
	WRITE_NIXIE_F	2, data_latD10	
	
MAIN_LAT_2a:	
	WRITE_NIXIE_F	3, data_latD01	
	WRITE_NIXIE_L	4, _char_dot
	
	;fraction
	; 4538.10504,N
	; max to int 5 999 999 -> 24bit (color)
	;(mm + mmfraction_to_int) / 60
	MOVLW	data_latM10
	CALL	Conv_Str_to_Fract
	
	WRITE_SERIAL_L	'i'
	MOVc	D88_Denum, IntToConvert
	CALL	WriteHexColor	
	
	FAR_CALL	DIV60c		; D88_Fract = D88_Num / 60, D88_Num = D88_Num % 60
	
	WRITE_SERIAL_L	'/'
	MOVc	D88_Fract, IntToConvert
	CALL	WriteHexColor
	
	CALL	ColorToBCD
	WRITE_SERIAL_L	'B'
	MOVi	BCD_Result, IntToConvert
	CALL	WriteHexInteger

	WRITE_NIXIE_F	5, data_buffer + 3
	WRITE_NIXIE_F	6, data_buffer + 4
	WRITE_NIXIE_F	7, data_buffer + 5
	WRITE_NIXIE_F	8, data_buffer + 6
	WRITE_NIXIE_F	9, data_buffer + 8 ; 7 is dot

	GOTO	ErrorCheck1

Draw_No_Lat:
	CALL 	WAIT_DATA
	
	WRITE_SERIAL_L	'N'
	WRITE_SERIAL_L	'L'
	WRITE_SERIAL_L	'A'
	WRITE_SERIAL_L	'T'
	
	GOTO	ErrorCheck1



;#############################################################################
;	Longitude display 
;#############################################################################

MAIN_LONG:
	MOVLW	_index_Long
	CALL	READ_NEXT		; wait and read CSV data at index 1
	BW_False	Draw_No_Long
	
	WRITE_SERIAL_F		data_unit
	WRITE_SERIAL_L		' '
	
	; direction
	CMP_lf	'E', data_unit
	BR_EQ	MAIN_LONG_1E
	CMP_lf	'W', data_unit
	BR_EQ	MAIN_LONG_1W
	GOTO	MAIN_LONG_2	
MAIN_LONG_1E:
	WRITE_NIXIE_L	0, _char_plus
	GOTO	MAIN_LONG_2
MAIN_LONG_1W:
	WRITE_NIXIE_L	0, _char_minus
MAIN_LONG_2:
	; ,07318.12345,W,
	;degrees
	; dont draw if 0
	CMP_lf	0, data_longD100
	BR_EQ	MAIN_LONG_2a
	WRITE_NIXIE_F	1, data_longD100
MAIN_LONG_2a:
	CMP_lf	0, data_longD010
	BR_EQ	MAIN_LONG_2b
	WRITE_NIXIE_F	2, data_longD010
MAIN_LONG_2b:
	WRITE_NIXIE_F	3, data_longD001	
	WRITE_NIXIE_L	4, _char_dot

	;fraction
	; 4538.10504,N
	; max to int 5 999 999 -> 24bit (color)
	;(mm + mmfraction_to_int) / 60

	MOVLW	data_longM10
	CALL	Conv_Str_to_Fract
	
	WRITE_SERIAL_L	'i'
	MOVc	D88_Denum, IntToConvert
	CALL	WriteHexColor	
	
	FAR_CALL	DIV60c		; D88_Fract = D88_Num / 60, D88_Num = D88_Num % 60
	
	WRITE_SERIAL_L	'/'
	MOVc	D88_Fract, IntToConvert
	CALL	WriteHexColor
	
	CALL	ColorToBCD
	WRITE_SERIAL_L	'B'
	MOVi	BCD_Result, IntToConvert
	CALL	WriteHexInteger

	WRITE_NIXIE_F	5, data_buffer + 3
	WRITE_NIXIE_F	6, data_buffer + 4
	WRITE_NIXIE_F	7, data_buffer + 5
	WRITE_NIXIE_F	8, data_buffer + 6
	WRITE_NIXIE_F	9, data_buffer + 8 ; 7 is dot


	GOTO	ErrorCheck1

Draw_No_Long:
	CALL 	WAIT_DATA
	
	WRITE_SERIAL_L	'N'
	WRITE_SERIAL_L	'L'
	WRITE_SERIAL_L	'O'
	WRITE_SERIAL_L	'N'
	WRITE_SERIAL_L	'G'
	
	GOTO	ErrorCheck1



;#############################################################################
;	Serial module error check and reporting 
;#############################################################################
	
ErrorCheck1:
	BTFBC	Serial_Status, _Serial_bit_RX_overrunError, ErrorCheck2
	WRITE_SERIAL_L	' '
	WRITE_SERIAL_L	'O'
	WRITE_SERIAL_L	'E'
	WRITE_SERIAL_L	'R'
	
ErrorCheck2:
	BTFBC	Serial_Status, _Serial_bit_RX_frameError, ErrorCheck3
	WRITE_SERIAL_L	' '
	WRITE_SERIAL_L	'F'
	WRITE_SERIAL_L	'E'
	WRITE_SERIAL_L	'R'
	
ErrorCheck3:
	BTFBC	Serial_Status, _Serial_bit_RX_bufferOverrun, ErrorCheck_End
	WRITE_SERIAL_L	' '
	WRITE_SERIAL_L	'R'
	WRITE_SERIAL_L	'B'
	WRITE_SERIAL_L	'E'
	WRITE_SERIAL_L	'R'
	
ErrorCheck_End:
	WRITE_SERIAL_L	13		;(CR)
	WRITE_SERIAL_L	10		;(LF)



;#############################################################################
;	End of main loop
;#############################################################################
	
	CLRF	Serial_Status
	CALL	Nixie_Send
	
	GOTO	LOOP



;#############################################################################
;	Subroutines
;#############################################################################

WAIT_DATA:
	BSF	Serial_Status, _Serial_bit_RX_inhibit
	MOVLW	_char_dot
	INCF	NixieDemoCount, F
	BTFSC	NixieDemoCount, 0
	MOVLW	_char_topdot
	WRITE_NIXIE_W	0
	RETURN
	
;#############################################################################
;	Serial TX
;#############################################################################

; convert 0-9 value to ascii '0' to '9' before sending
Serial_TX_write_ITOA:
	MOVLW	'0'
	ADDWF	Serial_Data, F
	
; block wait for availble space in the TX buffer then write the byte
Serial_TX_write:
	BSF	Step3_green

	INCF	Serial_TX_buffer_wp, W	; calculate next possible write pointer position
	MOVWF	TX_Temp
	CMP_lf	_Serial_TX_buffer_endAddress, TX_Temp
	BR_NE	Serial_TX_write_2
	STR	_Serial_TX_buffer_startAddress, TX_Temp
Serial_TX_write_2:
	CMP_ff	Serial_TX_buffer_rp, TX_Temp	; compare to current read pointer
	BR_EQ	Serial_TX_write
	
	BANK0_1
	BCF	PIE1, TXIE	; disable tx interrupts
	;BTFSC	TXSTA, TRMT
	;GOTO
	;MOVF	Serial_Data, W
	;MOVWF	TXREG
	
;Serial_TX_write_3:
	BANK1_0
	
	WRITEp	Serial_Data, Serial_TX_buffer_wp	
	MOV	TX_Temp, Serial_TX_buffer_wp
	BANK0_1
	BSF	PIE1, TXIE	; enable tx interrupts	
	BANK1_0
	
	;BTFSS	PIR1, TXIF
	;RETURN
	;MOVF	Serial_Data, W
	;MOVWF	TXREG
	;BCF	Wait_TX_red
	
	BCF	Step3_green
	RETURN



;#############################################################################
;	Serial RX
;#############################################################################

; block wait for availble data then read RX buffer
Serial_RX_waitRead:
;	BSF	Wait_RX_red
	CMP_ff	Serial_RX_buffer_wp, Serial_RX_buffer_rp
	BR_EQ	Serial_RX_waitRead
	READp	Serial_RX_buffer_rp, Serial_Data
	INCF	Serial_RX_buffer_rp, F
	;BCF	Wait_RX_red
	CMP_lf	_Serial_RX_buffer_endAddress, Serial_RX_buffer_rp
	SK_EQ
	RETURN
	STR	_Serial_RX_buffer_startAddress, Serial_RX_buffer_rp
	RETURN



;#############################################################################
;	Nixie Tube Serial (74x595) 10 tubes X 9 segments
;#############################################################################

; light up all segments
Nixie_All: ;()[NixieLoop]
	MOVLW	NixieBuffer
	MOVWF	FSR
	STR	10, NixieLoop
Nixie_All_Next:
	CLRF	INDF
	INCF	FSR, F
	DECFSZ	NixieLoop, F
	GOTO	Nixie_All_Next	
	RETURN	

; Turn all segments off
Nixie_None: ;()[NixieLoop]
	MOVLW	NixieBuffer
	MOVWF	FSR
	STR	10, NixieLoop
	MOVLW	0xFF
Nixie_None_Next:
	MOVWF	INDF
	INCF	FSR, F
	DECFSZ	NixieLoop, F
	GOTO	Nixie_None_Next
	RETURN

; Turn off all segments of 1 tube
Nixie_ClearTube: ;(NixieTube)[NixieLoop, WriteLoop, NixieVarX, NixieVarY]
	MOVF	NixieTube, W
	CALL	Nixie_MaxSeg	; get number of segments for the tube
	MOVWF	NixieLoop
	
	MOVF	NixieTube, W
	CALL	Nixie_Offsets	; get the bit offset for that tube
	MOVWF	NixieVarX	; offset, will be lost each write
	MOVWF	WriteLoop	; offset to keep original value
	
Nixie_ClearTube_Loop:
	CLRF	NixieVarY	; to receive remainder
	BCF	STATUS, C	; div and mod bit number to get byte and bit offsets
	RRF	NixieVarX, F	; / 2
	RRF	NixieVarY, F	
	BCF	STATUS, C
	RRF	NixieVarX, F	; / 4
	RRF	NixieVarY, F	
	BCF	STATUS, C
	RRF	NixieVarX, F	; / 8
	RRF	NixieVarY, F	
	BCF	STATUS, C	; shift modulo 1 more time to align with nibble
	RRF	NixieVarY, F
	SWAPF	NixieVarY, F
	
	MOVLW	NixieBuffer	; @data
	ADDWF	NixieVarX, W	; + byte offset
	MOVWF	FSR		; FSR = @data[di]
	BSet	INDF, 	NixieVarY ; Y = bit offset
	
	INCF	WriteLoop, F
	MOV	WriteLoop, NixieVarX	;next segment in X
	DECFSZ	NixieLoop, F
	GOTO	Nixie_ClearTube_Loop
	RETURN

; light up 1 segment, seg# in NixieSeg, tube# in NixieTube
Nixie_SetSegment: ;(NixieSeg, NixieTube)[NixieVarX, NixieVarY]

	MOVLW	high (TABLE0)
	MOVWF	PCLATH
	
	MOVF	NixieTube, W
	CALL	Nixie_MaxSeg	; get number of segments for the tube
	SUBWF	NixieSeg, W	; w = seg# - max, borrow should be set (carry cleared)
	BTFSC	STATUS, C
	RETURN	
	
	MOVF	NixieTube, W
	CALL	Nixie_Offsets	; get the bit offset for that tube
	ADDWF	NixieSeg, W	; NixieVarX = offset + seg#
	MOVWF	NixieVarX

	CLRF	NixieVarY	; to receive remainder
	BCF	STATUS, C
	RRF	NixieVarX, F	; / 2
	RRF	NixieVarY, F	
	BCF	STATUS, C
	RRF	NixieVarX, F	; / 4
	RRF	NixieVarY, F	
	BCF	STATUS, C
	RRF	NixieVarX, F	; / 8
	RRF	NixieVarY, F	
	BCF	STATUS, C	; shift modulo 1 more time to align with nibble
	RRF	NixieVarY, F
	SWAPF	NixieVarY, F
	
	MOVLW	NixieBuffer	; @data
	ADDWF	NixieVarX, W
	MOVWF	FSR		; FSR = @data[di]
	BClear	INDF, 	NixieVarY	
	RETURN

; Draw a num [0-9], char code in NixieData, tube in NixieTube
Nixie_DrawNum:	;(NixieData) [NixieLoop]
; CALL	Nixie_SetSegment:(NixieSeg, NixieTube)[NixieVarX, NixieVarY]

	MOVLW	high (TABLE0)
	MOVWF	PCLATH	
	MOVF	NixieData, W
	CALL	Nixie_Num_seg8
	MOVWF	NixieLoop
	
	STR	8, NixieSeg	
	BTFSC	NixieLoop, 0 ; test seg 8
	CALL	Nixie_SetSegment
	
	MOVF	NixieData, W
	CALL	Nixie_Num_seg0_7
	MOVWF	NixieLoop

Nixie_DrawNum_loop:
	DECF	NixieSeg, F
	RLF	NixieLoop, F
	BTFSC	STATUS, C
	CALL	Nixie_SetSegment
	INCF	NixieSeg, F
	DECFSZ	NixieSeg, F
	GOTO	Nixie_DrawNum_loop
	
	RETURN	

;Send the data to the SIPO buffers, LSBit of LSByte first
Nixie_Send: ;()[WriteLoop, NixieLoop]

	MOVLW	NixieBuffer
	MOVWF	FSR
	STR	10, WriteLoop
Nixie_Send_Next_Byte:
	STR	8, NixieLoop
	
Nixie_Send_Next_Bit:
	BCF	NixieSerial_Data
	RRF	INDF, F
	BTFSC	STATUS, C
	BSF	NixieSerial_Data
	
	BSF	NixieSerial_Clock
	BCF	NixieSerial_Clock
	
	DECFSZ	NixieLoop, F
	GOTO	Nixie_Send_Next_Bit
	
	INCF	FSR, F
	DECFSZ	WriteLoop, F
	GOTO	Nixie_Send_Next_Byte
	
	BSF	NixieSerial_Latch
	BCF	NixieSerial_Latch
	
	RETURN



;#############################################################################
;	GPS serial read and parse
;#############################################################################

WAIT_GPGGA_HEADER:
	BCF	Serial_Status, _Serial_bit_RX_inhibit
	
	CALL	Serial_RX_waitRead
	CMP_lf	'$', Serial_Data
	BR_NE	WAIT_GPGGA_HEADER
	
	CALL	Serial_RX_waitRead
	CMP_lf	'G', Serial_Data
	BR_NE	WAIT_GPGGA_HEADER

	CALL	Serial_RX_waitRead
	CMP_lf	'P', Serial_Data
	BR_NE	WAIT_GPGGA_HEADER
	
	CALL	Serial_RX_waitRead
	CMP_lf	'G', Serial_Data
	BR_NE	WAIT_GPGGA_HEADER
	
	CALL	Serial_RX_waitRead
	CMP_lf	'G', Serial_Data
	BR_NE	WAIT_GPGGA_HEADER
	
	CALL	Serial_RX_waitRead
	CMP_lf	'A', Serial_Data
	BR_NE	WAIT_GPGGA_HEADER
	
	CALL	Serial_RX_waitRead
	CMP_lf	',', Serial_Data
	BR_NE	WAIT_GPGGA_HEADER

	BSF	Step2_yellow
	RETURN



; $GPGGA,205654.00,
READ_NEXT_TIME:
	CALL	WAIT_GPGGA_HEADER
		
	CALL	Serial_RX_waitRead
	CMP_lf	',', Serial_Data
	SK_NE
	RETLW	FALSE
	MOV	Serial_Data, data_H10
	
	CALL	Serial_RX_waitRead
	MOV	Serial_Data, data_H01
	
	CALL	Serial_RX_waitRead
	MOV	Serial_Data, data_m10
	
	CALL	Serial_RX_waitRead
	MOV	Serial_Data, data_m01
	
	CALL	Serial_RX_waitRead
	MOV	Serial_Data, data_s10
	
	CALL	Serial_RX_waitRead
	MOV	Serial_Data, data_s01
	
	BSF	Serial_Status, _Serial_bit_RX_inhibit
	
	MOVLW	'0'
	SUBWF	data_H10, F
	SUBWF	data_H01, F
	SUBWF	data_m10, F
	SUBWF	data_m01, F
	SUBWF	data_s10, F
	SUBWF	data_s01, F
	
	BCF	Step2_yellow
	RETLW	TRUE



; $GPGGA,205647.91,          , ,           , ,0,00,99.99,   , ,     , ,,*6C
; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,39.6,M,-32.4,M,,*59
; $GPGGA,  time   , lat      ,N, long      ,W,x,x , x  , ALT,U
;          0        1         2  3          4 5 6   7     8  9
; read next GPGGA CSV data, requested index is passed in W, index 0 is the time, fetched in READ_NEXT_TIME
READ_NEXT:
	MOVWF	NixieVarX		; save index 
	CALL	WAIT_GPGGA_HEADER
	
READ_NEXT_SEEK:
	CALL	Serial_RX_waitRead	; wait for next ','
	CMP_lf	',', Serial_Data
	BR_NE	READ_NEXT_SEEK	

	DECFSZ	NixieVarX, F		; dec index
	GOTO	READ_NEXT_SEEK		; if not 0 seek another ','
	
	CALL	Serial_RX_waitRead
	CMP_lf	',', Serial_Data	; if already another ',' return false
	SK_NE
	RETLW	FALSE
	
	MOV	Serial_Data, data_buffer	; data_buffer[0] = Serial_Data
	
	STR	data_buffer, NixieVarX	; x = @data_buffer
	INCF	NixieVarX, F			; x++

READ_NEXT_READ_DATA:
	CALL	Serial_RX_waitRead	
	
	CMP_lf	',', Serial_Data
	BR_EQ	READ_NEXT_CONVERT		; convert after receiving a ','
	
	WRITEp	Serial_Data, NixieVarX	; data_buffer[x] = Serial_Data
	INCF	NixieVarX, F			; ptr++
	GOTO	READ_NEXT_READ_DATA	
	
READ_NEXT_CONVERT:
	MOV	NixieVarX, FSR
	STR	END_MARKER, INDF
	
READ_NEXT_CONVERT_LOOP:
	DECF	FSR, F			; ptr--
	MOVLW	'0'			; subtract ord('0') from each bytes until pointer is back to @data_buffer
	SUBWF	INDF, F
	CMP_lf	data_buffer, FSR
	BR_NE	READ_NEXT_CONVERT_LOOP
	
	CALL	Serial_RX_waitRead	; read first char of next value, usually the unit of the preceding one
	MOV	Serial_data, data_unit
	
	BSF	Serial_Status, _Serial_bit_RX_inhibit
	
	BCF	Step2_yellow
	RETLW	TRUE



;#############################################################################
;	Timezone adjust
;#############################################################################

ADJUST_TZ:
	BCF	STATUS, C
	RLF	data_H10, F ; h10  = 2*h10
	MOVF	data_H10, W ; w = 2*h10
	BCF	STATUS, C
	RLF	data_H10, F ; h10  = 4*h10
	RLF	data_H10, F ; h10  = 8*h10
	ADDWF	data_H10, W
	
	ADDWF	data_H01, F ; h01 = 10*h10 + h01 = HH(utc)
	
	SUB	data_H01, TZ_offset ; h01 = HH(EDT/EST)
	BR_NB	ADJUST_TZ_NB
	ADDL	data_H01, 24 ; if borrow, roll hour over
ADJUST_TZ_NB:
	CLRF	data_H10
	CMP_lf	10, data_H01
	BR_LE	ADJUST_TZ_10	; if 10 <= H01
	RETURN			; else return
ADJUST_TZ_10:
	INCF	data_H10, F
	SUBL	data_H01, 10
	
	CMP_lf	10, data_H01
	BR_LE	ADJUST_TZ_20	; if 10 <= H01
	RETURN			; else return
ADJUST_TZ_20:
	INCF	data_H10, F
	SUBL	data_H01, 10
	RETURN



;#############################################################################
;	Serial formatting and helpers
;#############################################################################

; Convert byte (8 bit int) to hex and send over serial
WriteHexByte:
	MOVLW	high (TABLE0)
	MOVWF	PCLATH
	SWAPF	IntToConvert, W
	ANDLW	0x0F
	CALL	NibbleHex
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	MOVF	IntToConvert, W
	ANDLW	0x0F
	CALL	NibbleHex
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	MOVLW	' '
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	RETURN

; Convert short (16 bit int) to hex and send over serial
WriteHexShort:
	MOVLW	high (TABLE0)
	MOVWF	PCLATH
	SWAPF	IntToConvert + 1, W
	ANDLW	0x0F
	CALL	NibbleHex
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	MOVF	IntToConvert + 1, W
	ANDLW	0x0F
	CALL	NibbleHex
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	
	SWAPF	IntToConvert, W
	ANDLW	0x0F
	CALL	NibbleHex
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	MOVF	IntToConvert, W
	ANDLW	0x0F
	CALL	NibbleHex
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	
	MOVLW	' '
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	RETURN
	
; Convert color (24 bit int) to hex and send over serial
WriteHexColor:
	STR	3, WAIT_loopCounter1
	STR	IntToConvert + 2, WAIT_loopCounter2
	
	MOVLW	high (TABLE0)
	MOVWF	PCLATH	
WriteHexColor_loop:
	MOV	WAIT_loopCounter2, FSR
	SWAPF	INDF, W
	ANDLW	0x0F
	CALL	NibbleHex
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	
	MOV	WAIT_loopCounter2, FSR
	MOVF	INDF, W
	ANDLW	0x0F
	CALL	NibbleHex
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	
	DECF	WAIT_loopCounter2, F
	DECFSZ	WAIT_loopCounter1, F
	GOTO	WriteHexColor_loop
	
	MOVLW	' '
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	RETURN
	
; Convert int (32 bit int) to hex and send over serial
WriteHexInteger:
	STR	4, WAIT_loopCounter1
	STR	IntToConvert + 3, WAIT_loopCounter2
	
	MOVLW	high (TABLE0)
	MOVWF	PCLATH
WriteHexInteger_loop:
	MOV	WAIT_loopCounter2, FSR
	SWAPF	INDF, W
	ANDLW	0x0F
	CALL	NibbleHex
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	MOV	WAIT_loopCounter2, FSR
	MOVF	INDF, W
	ANDLW	0x0F
	CALL	NibbleHex
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	
	DECF	WAIT_loopCounter2, F
	DECFSZ	WAIT_loopCounter1, F
	GOTO	WriteHexInteger_loop
	
	MOVLW	' '
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	RETURN

; 24 bit int -> 32 bit packed bcd 16 77 72 15
ColorToBCD:	
	CLRFi	BCD_Result
	STR	23, NixieLoop	;Rotate and Increment 23 time
	
ColorToBCD_Rotate:
 	BCF	STATUS,C
	RLFc	IntToConvert
	;RLF	IntToConvert + 1, F
	;RLF	IntToConvert + 2, F
	RLFi	BCD_Result
	;RLF	BCD_Result + 1, F
	;RLF	BCD_Result + 2, F
	;RLF	BCD_Result + 3, F

	STR	BCD_Result, FSR
	
ColorToBCD_HighNibble:	
	SWAPF	INDF, W
	ANDLW	0x0F
	SUBLW	4
	BR_NB	ColorToBCD_LowNibble
	ADDL	INDF, 0x30
	
ColorToBCD_LowNibble:
	MOVF	INDF, W
	ANDLW	0x0F
	SUBLW	4
	BR_NB	ColorToBCD_CheckNext
	ADDL	INDF, 0x03
	
ColorToBCD_CheckNext:
	INCF	FSR, F
	CMP_lf	BCD_Result + 4, FSR
	SK_EQ
	GOTO	ColorToBCD_HighNibble

	DECFSZ	NixieLoop, F
	GOTO	ColorToBCD_Rotate

 	BCF	STATUS,C		;24th time Shift only, no "add 3 if > 4"
	RLFc	IntToConvert
	RLFi	BCD_Result
	
; expand BCD_Result to serial_data
; 32 bit packed bcd (16 77 72 15) to 1 byte per BCD 1 6 7 7 7 2 1 5
;	skipping first destination char if '-'
;	unpack to bytes in destination
;	add '.' before last char
;	add END_MARKER at the end
;	skipping leading 0s by bubbling data back to the start of destination
ExpandBCD_10th:
	;STR	BCD_Result, NixieVarX		; X = @bcd
	STR	data_buffer, NixieVarY	; Y = @data	
	
;	MOVF	serial_data, F	; skip "-" in data
	CMP_lf	CONV_MINUS, data_buffer
	SK_NE
	INCF	NixieVarY, F	; skip first byte of data if "-"
	
	; Expand
	MOV	NixieVarY, FSR
	SWAPF	BCD_Result + 3, W
	ANDLW	0x0F
	MOVWF	INDF	
	INCF	FSR, F
	MOVF	BCD_Result + 3, W
	ANDLW	0x0F
	MOVWF	INDF
	
	INCF	FSR, F
	SWAPF	BCD_Result + 2, W
	ANDLW	0x0F
	MOVWF	INDF	
	INCF	FSR, F
	MOVF	BCD_Result + 2, W
	ANDLW	0x0F
	MOVWF	INDF
	
	INCF	FSR, F
	SWAPF	BCD_Result + 1, W
	ANDLW	0x0F
	MOVWF	INDF	
	INCF	FSR, F
	MOVF	BCD_Result + 1, W
	ANDLW	0x0F
	MOVWF	INDF
	
	INCF	FSR, F
	SWAPF	BCD_Result, W
	ANDLW	0x0F
	MOVWF	INDF
	
	INCF	FSR, F
	STR	CONV_DOT, INDF
		
	INCF	FSR, F
	MOVF	BCD_Result, W
	ANDLW	0x0F
	MOVWF	INDF
	
	INCF	FSR, F
	STR	END_MARKER, INDF
	
	RETURN
	
	; skip leading 0s
ExpandBCD_trimLeft:
	MOV	NixieVarY, FSR ; start of buffer
	MOVF	INDF, W		; until not 0
	SK_ZE
	RETURN
	CMP_lf	END_MARKER, INDF ; or end marker
	SK_NE
	RETURN
	
	;MOV	NixieVarY, FSR	; start of buffer
ExpandBCD_trimLeft_loop:	; move next byte to previous location
	INCF	FSR, F; next
	MOVF	INDF, W
	DECF	FSR, F; previous
	MOVWF	INDF
	INCF	FSR, F; next
	
	CMP_lf	END_MARKER, INDF ; until end marker
	SK_EQ
	GOTO	ExpandBCD_trimLeft_loop

	GOTO	ExpandBCD_trimLeft



; convert data_buffer string to int in D88_Denum
Conv_Str_to_Int:	
	STR	data_buffer, NixieVarX	; NixieVarX = @data_buffer
	CMP_lf	CONV_MINUS, data_buffer
	SK_NE	
	INCF	NixieVarX, F	; skip the Minus sign
	
	CLRFc	D88_Num		;temp
	CLRFc	D88_Denum	;result
	READp	NixieVarX, D88_Denum	; D88_Denum = first value
	
Conv_Str_to_Int_loop:
	CLRFc	D88_Modulo	
	INCF	NixieVarX, F	;next char
	READp	NixieVarX, D88_Modulo	; D88_Modulo = next value
	
	CMP_lf	CONV_DOT, D88_Modulo	; if next is dot stop converting to int
	SK_NE	
	RETURN
	CMP_lf	END_MARKER, D88_Modulo; to be safe also check for end of string marker
	SK_NE	
	RETURN

	FAR_CALL	MULT10s		; D88_Num = D88_Denum * 10
	MOVc	D88_Num, D88_Denum	; D88_Denum = D88_Num
	ADDc	D88_Denum, D88_Modulo	; D88_Denum = D88_Denum + D88_Modulo 
	GOTO	Conv_Str_to_Int_loop



; convert data_buffer string to int in D88_Denum
; ignoring dot, starting at position in W
Conv_Str_to_Fract:
	MOVWF	NixieVarX	; NixieVarX = @startAddress
	CLRFc	D88_Num		;temp
	CLRFc	D88_Denum	;result
	READp	NixieVarX, D88_Denum	; D88_Denum = first value
	
Conv_Str_to_Fract_loop:
	CLRFc	D88_Modulo
	INCF	NixieVarX, F	;next char
	READp	NixieVarX, D88_Modulo	; D88_Modulo = next value
	
	CMP_lf	END_MARKER, D88_Modulo; until end marker
	SK_NE
	RETURN
	CMP_lf	END_MARKER - '0', D88_Modulo; until end marker
	SK_NE
	RETURN
	
	CMP_lf	CONV_DOT, D88_Modulo	; skip if '.'
	SK_NE	
	GOTO	Conv_Str_to_Fract_loop

	FAR_CALL	MULT10c		; D88_Num = D88_Denum * 10
	MOVc	D88_Num, D88_Denum	; D88_Denum = D88_Num
	ADDc	D88_Denum, D88_Modulo	; D88_Denum = D88_Denum + D88_Modulo 
	GOTO	Conv_Str_to_Fract_loop

;#############################################################################
;	Tables
;#############################################################################

;	PC0x0100ALIGN	TABLE0	; set the label and align to next 256 byte boundary in program memory
TABLE0:
; 	Int to Hex nibble char table
NibbleHex:
	ADDWF	PCL, F
	dt	"0123456789ABCDEF"

;	Nixie Segments offset

Nixie_Offsets: ; segments starting bit offset of each tubes
	ADDWF	PCL, F
	dt	0,  4, 13, 22, 31, 35, 44, 53, 62, 71
Nixie_MaxSeg:
	ADDWF	PCL, F
	dt	4,  9,  9,  9,  4,  9,  9,  9,  9,  9

Nixie_Num_seg0_7:
	ADDWF	PCL, F
	   ;     'hgfedcba'
	RETLW	b'00110101' ;0
	RETLW	b'00000000' ;1
	RETLW	b'01110110' ;2
	RETLW	b'11110100' ;3
	RETLW	b'01001000' ;4
	RETLW	b'10111100' ;5
	RETLW	b'10110111' ;6
	RETLW	b'00000100' ;7
	RETLW	b'11111110' ;8
	RETLW	b'01001100' ;9
	RETLW	b'00000100' ;. 10
	RETLW	b'00000110' ;: 11
	RETLW	b'00000001' ;- 12
	RETLW	b'00001001' ;+ 13
	RETLW	b'00111110' ;E 14
	RETLW	b'00110101' ;C 15
	RETLW	b'00001101' ;F 16
	RETLW	b'01001001' ;M 17
	RETLW	b'00000010' ;topdot 18
	RETLW	b'00100000' ;, 19
	RETLW	b'01001101' ;A 20
	RETLW	b'00000101' ;T 21
	
Nixie_Num_seg8:
	ADDWF	PCL, F
	    ;    '       i'
	RETLW	b'00000001' ;0
	RETLW	b'00000001' ;1
	RETLW	b'00000000' ;2
	RETLW	b'00000000' ;3
	RETLW	b'00000001' ;4
	RETLW	b'00000000' ;5
	RETLW	b'00000000' ;6
	RETLW	b'00000001' ;7
	RETLW	b'00000000' ;8
	RETLW	b'00000001' ;9
	RETLW	b'00000000' ;. 10
	RETLW	b'00000000' ;: 11
	RETLW	b'00000000' ;- 12
	RETLW	b'00000000' ;+ 13
	RETLW	b'00000000' ;E 14
	RETLW	b'00000000' ;C 15
	RETLW	b'00000000' ;F 16
	RETLW	b'00000001' ;M 17
	RETLW	b'00000000' ;topdot 18
	RETLW	b'00000000' ;, 19
	RETLW	b'00000001' ;A 20
	RETLW	b'00000000' ;T 21
	; a -> HBar
	; b -> TDot
	; c -> BDot
	; d -> VBar



;#############################################################################
;	PC 0x800 (1k) boundary
;#############################################################################

	PC0x0800SKIP



;#############################################################################
;	Math
;#############################################################################

;idx '0000 0000  0000 0001'
; 33 '0000 0000  0010 0001' b0
; 33 '1000 0100  0000 0000' b10
;idx '0000 0100  0000 0000'
DIV33c:	; div by 33, 24 bit ; D88_Fract = D88_Num / 33, D88_Num = D88_Num % 33
	CLRFc	D88_Fract
	;STRc	b'0000 0100  0000 0000  0000 0000', D88_Modulo
	;STRc	b'1000 0100  0000 0000  0000 0000', D88_Denum
	
	STRc	0x040000, D88_Modulo
	STRc	0x840000, D88_Denum
	
_DIV33c_loop:
	SUBc	D88_Num, D88_Denum
	BR_GT	_DIV33c_pos
	BR_LT	_DIV33c_neg
;if equal
	ADDc	D88_Fract, D88_Modulo
	FAR_RETURN
_DIV33c_pos:
	ADDc	D88_Fract, D88_Modulo
	GOTO	_DIV33c_roll
_DIV33c_neg:
	ADDc	D88_Num, D88_Denum
_DIV33c_roll:
	BCF	STATUS, C
	RRFc	D88_Denum
	BCF	STATUS, C
	RRFc	D88_Modulo
	
	BTFSS	STATUS, C
	GOTO	_DIV33c_loop
	FAR_RETURN

;60 = 0x3C = b'00111100'
;01 = 0x01 = b'00000001'
;     0xF0 = b'11110000'
;     0x04 = b'00000100'
DIV60c:	; div by 60, 24 bit ; D88_Fract = D88_Num / 33, D88_Num = D88_Num % 60
	CLRFc	D88_Fract
	
	STRc	0x040000, D88_Modulo
	STRc	0xF00000, D88_Denum
	
_DIV60c_loop:
	SUBc	D88_Num, D88_Denum
	BR_GT	_DIV60c_pos
	BR_LT	_DIV60c_neg
;if equal
	ADDc	D88_Fract, D88_Modulo
	FAR_RETURN
_DIV60c_pos:
	ADDc	D88_Fract, D88_Modulo
	GOTO	_DIV60c_roll
_DIV60c_neg:
	ADDc	D88_Num, D88_Denum
_DIV60c_roll:
	BCF	STATUS, C
	RRFc	D88_Denum
	BCF	STATUS, C
	RRFc	D88_Modulo
	
	BTFSS	STATUS, C
	GOTO	_DIV60c_loop
	FAR_RETURN



MULT33s: ; 33 = 1 + 32 ; D88_Num (24 bit) = D88_Denum (16 bit, expanded to 24) * 33
	CLRF	D88_Denum + 2	
	MOVc	D88_Denum, D88_Num	; D88_Num = a
	
	BCF	STATUS, C
	RLFc	D88_Denum	; a = a * 2
		
	BCF	STATUS, C
	RLFc	D88_Denum	; a = a * 4
	
	BCF	STATUS, C
	RLFc	D88_Denum	; a = a * 8
	
	BCF	STATUS, C
	RLFc	D88_Denum	; a = a * 16
	
	BCF	STATUS, C
	RLFc	D88_Denum	; a = a * 32
	
	ADDc	D88_Num, D88_Denum 	; D88_Num = a + 32*a = 33*a
	
	FAR_RETURN

	
MULT10s: ; D88_Num (24 bit) = D88_Denum (16 bit, expanded to 24) * 10
; 0000 1010
; *2 + *8
	CLRF	D88_Denum + 2
	
	BCF	STATUS, C
	RLFc	D88_Denum	; *2
	
	MOVc	D88_Denum, D88_Num 	; D88_Num = 2*a
	
	BCF	STATUS, C
	RLFc	D88_Denum	; *4
	
	BCF	STATUS, C
	RLFc	D88_Denum	; *8
	
	ADDc	D88_Num, D88_Denum	; D88_Num = 2*a + 8*a = 10*a
	
	FAR_RETURN
	
MULT10c: ; D88_Num (32 bit) = D88_Denum (24 bit expanded to 32) * 10
; 0000 1010
; *2 + *8
	CLRF	D88_Denum + 3
	
	BCF	STATUS, C
	RLFi	D88_Denum	; *2
	
	MOVi	D88_Denum, D88_Num 	; D88_Num = 2*a
	
	BCF	STATUS, C
	RLFi	D88_Denum	; *4
	
	BCF	STATUS, C
	RLFi	D88_Denum	; *8
	
	ADDi	D88_Num, D88_Denum	; D88_Num = 2*a + 8*a = 10*a
	
	FAR_RETURN
	
	
MULT100s: ; D88_Num (24 bit) = D88_Denum (16 bit, expanded to 24) * 100
; 0110 0100
; *4 + *32 + *64
	CLRF	D88_Denum + 2
	
	BCF	STATUS, C
	RLFc	D88_Denum	; *2
	BCF	STATUS, C
	RLFc	D88_Denum	; *4
	
	MOVc	D88_Denum, D88_Num 	; D88_Num = 4*a
	
	BCF	STATUS, C
	RLFc	D88_Denum	; *8	
	BCF	STATUS, C
	RLFc	D88_Denum	; *16
	BCF	STATUS, C
	RLFc	D88_Denum	; *32
	
	ADDc	D88_Num, D88_Denum	; D88_Num = 4*a + 32*a
	
	BCF	STATUS, C
	RLFc	D88_Denum	; *64
	
	ADDc	D88_Num, D88_Denum	; D88_Num = 4*a + 32*a + 64*a
	
	FAR_RETURN


;#############################################################################
;	Delay routines	for 8MHz
;#############################################################################

WAIT_1s:
	MOVLW	10
	MOVWF	WAIT_loopCounter1
	
WAIT_1s_loop1:
	MOVLW	200			; (1) for 100 ms
	MOVWF	WAIT_loopCounter2	; (1)

WAIT_1s_loop2:			; 0.5ms / loop1
	MOVLW	250 - 2			; (1) 250 loops of 4 cycles (minus 2 loop for setup and next loop) 
	MOVWF	WAIT_loopCounter3	; (1) 
	NOP				; (1) 
	NOP				; (1) 

WAIT_1s_loop3:			; 4 cycles per loop (2us / loop2)
	NOP				; (1) 
	DECFSZ	WAIT_loopCounter3, F	; (1) 
	GOTO	WAIT_1s_loop3		; (2) 
	NOP				; (1) 
	
	NOP				; (1) 
	DECFSZ	WAIT_loopCounter2, F	; (1) 
	GOTO	WAIT_1s_loop2		; (2) 
	
	DECFSZ	WAIT_loopCounter1, F
	GOTO	WAIT_1s_loop1
	FAR_RETURN



;#############################################################################
;	End Declaration
;#############################################################################

	END
