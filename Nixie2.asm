;#############################################################################
;	Nixie GPS 2
;	GPS Time: read, parse, adjust timezone, display
;	GPS Alt: parse and convert M/FT
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
; pin  6 IO_ PORTB0	O WaitRX_red
; pin  7 IO_ PORTB1	
; pin  8 IOR PORTB2	I RX from GPS
; pin  9 IO_ PORTB3	I Mode Select bit 0

; pin 10 IO_ PORTB4	I Mode Select bit 1
; pin 11 IOT PORTB5	O TX to computer
; pin 12 IOA PORTB6	?(PGC)
; pin 13 IOA PORTB7	?(PGD)
; pin 14 PWR VDD	VCC
; pin 15 _O_ PORTA6	?XT
; pin 16 I__ PORTA7	?XT
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

#DEFINE WaitRX_red 		PORTB, 0

#DEFINE Mode_Select_b0	PORTB, 3
#DEFINE Mode_Select_b1	PORTB, 4

#DEFINE	END_MARKER		0xFF
#DEFINE	CONV_END_MARKER	END_MARKER - '0'
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

ByteToConvert		EQU	0x25 ; for convert to hex
TZ_offset		EQU	0x26 ; for TZ adjust
WriteLoop		EQU	0x27 ; for NixieSerial and WriteString
TX_Temp			EQU	0x28 ; for RX/TX buffer address calculation

data_buffer		EQU	0x29
data_H10		EQU	0x29 ; alias for static buffer positions
data_H01		EQU	0x2A
data_m10		EQU	0x2B
data_m01		EQU	0x2C
data_s10		EQU	0x2D
data_s01		EQU	0x2E

data_unit		EQU	0x4E ; M F N S E W
Display_Mode		EQU	0x4F 
_mode_Time				EQU	0
_mode_Lat				EQU	1
_mode_Long				EQU	2
_mode_Alt				EQU	3


NixieVarX		EQU	0x59 ; inner data
NixieVarY		EQU	0x5A ; inner data
NixieLoop		EQU	0x5B ; inner data
NixieSeg		EQU	0x5C ; to pass data between routines
NixieData		EQU	0x5D ; to pass data between routines
NixieTube		EQU	0x5E ; to pass data between routines
NixieDemoCount		EQU	0x5F ; global for demo

D88_Num			EQU	0x60 ; numerator for div and receive modulo (remainder)
D88_Denum		EQU	0x62 ; denumerator for div
D88_Fract		EQU	0x64 ; Receive fraction of div
D88_Modulo		EQU	0x66 ; Modulo for preset div, also index for arbitrary div

; GPR files in GPR for context saving
;STACK_FSR		EQU	0x6C
;STACK_SCRATCH		EQU	0x6D
;STACK_SCRATCH2	EQU	0x6E
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


; GPR files in shared GPR for instruction extensions
;SCRATCH		EQU	0x7C
;SCRATCH2		EQU	0x7D

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
	BR_LT	_invalidASCII
	CMP_lf	126, Serial_Data
	BR_GT	_invalidASCII
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
	
	BTFBS	PIR1, RCIF, ISR_RX	; check if RX interrupt
	BTFBS	PIR1, TXIF, ISR_TX	; check if TX interrupt
	
	GOTO	ISR_END 		; unkown interrupt
	
ISR_RX:
	BTFSC	RCSTA, FERR		; check for framing error
	BSF	Serial_Status, _Serial_bit_RX_frameError
	
ISR_RX1:
	WRITEp	RCREG, Serial_RX_buffer_wp
	
	INCF	Serial_RX_buffer_wp, F	; writePtr++	
	CMP_lf	_Serial_RX_buffer_endAddress, Serial_RX_buffer_wp ; warp around
	BR_NE	ISR_RX2	
	STR	_Serial_RX_buffer_startAddress, Serial_RX_buffer_wp

ISR_RX2:
	CMP_ff	Serial_RX_buffer_wp, Serial_RX_buffer_rp ; check for circular buffer overrun
	SK_NE		; skip if both buffer are not equal after moving the write pointer forward
	BSF	Serial_Status, _Serial_bit_RX_bufferOverrun
	
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
	STR	_mode_Time, Display_Mode
	
;welcome message

	CALL	Nixie_All
	CALL	Nixie_Send
	CALL	WAIT_1s	
	
	CALL	Nixie_None
	CALL	Nixie_Send
	CALL	WAIT_1s	
	
	CALL	Nixie_None
	WRITE_NIXIE_L	2, _char_E
	WRITE_NIXIE_L	3, _char_C
	WRITE_NIXIE_L	5, 2
	WRITE_NIXIE_L	6, 0
	WRITE_NIXIE_L	7, 2
	WRITE_NIXIE_L	8, 0
	CALL	Nixie_Send
	CALL	WAIT_1s	
	
; enable interrupts
	BSF	INTCON, PEIE ; peripheral int
	BSF	INTCON, GIE  ; global int	
	
	
	PC0x0100ALIGN		startUpMessage
	WRITESTRING_LN		"Nixie 2 - Time + Alt"



;#############################################################################
;	Main Loop	
;#############################################################################


	
LOOP:
	CALL	Nixie_None	
	
;	CLRF	Display_Mode
;	BTFSC	Mode_Select_b0
;	BSF	Display_Mode, 0
;	BTFSC	Mode_Select_b1
;	BSF	Display_Mode, 1

;	CMP_lf	_mode_Time, Display_Mode
;	BR_EQ	MAIN_TIME
;	GOTO	MAIN_TIME
	
;	CMP_lf	_mode_Alt, Display_Mode
;	BR_EQ	MAIN_ALT

	BTFSC	Mode_Select_b0
	GOTO	MAIN_ALT
	GOTO	MAIN_TIME
	
	; TODO test negative M OK
	; TODO test negative F OK
	; TODO FT to M
	; TODO M to FT	
	; TODO M >= 1000 OK
	; TODO negative M >= 1000 OK
	;; test strings:
	; Meters
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,1.2,M,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,12.3,M,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,123.4,M,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,1234.5,M,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,12345.6,M,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,123456.7,M,-32.4,M,,*59
	
	; Negative Meters
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-1.2,M,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-12.3,M,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-123.4,M,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-1234.5,M,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-12345.6,M,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-123456.7,M,-32.4,M,,*59
	
	; Feet
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,1.2,F,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,12.3,F,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,123.4,F,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,1234.5,F,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,12345.6,F,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,123456.7,F,-32.4,M,,*59
	
	; Negative Feet
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-1.2,F,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-12.3,F,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-123.4,F,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-1234.5,F,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-12345.6,F,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-123456.7,F,-32.4,M,,*59
	
	; Conversions
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,39.6,M,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,130.6,F,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,1234.5,M,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,4073.8,F,-32.4,M,,*59
	
	; Negative Conversions
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-39.6,M,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-130.6,F,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-1234.5,M,-32.4,M,,*59
	;; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,-4073.8,F,-32.4,M,,*59
	
;	CMP_lf	_mode_Lat, Display_Mode
;	BR_EQ	MAIN_LAT
	
;	CMP_lf	_mode_Long, Display_Mode
;	BR_EQ	MAIN_LONG
	
	WRITE_SERIAL_L	'?'
	CALL	Wait_1s

	GOTO	LOOP



;#############################################################################
;	Time display 
;#############################################################################

MAIN_TIME:
	WRITE_NIXIE_L	4, _char_column
;	WRITE_NIXIE_L	1, _char_T
	
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
	
	MOVLW	8
	CALL	READ_NEXT		; wait and read CSV data at index 8
	BW_False	Draw_No_alt

	; convert integer part to int
	; check unit
	; check requested unit
	; if different convert
	
	; Meters:
	; draw M
	; check if > 1000
	; 	draw integer part
	; else draw both parts
	
	; Feet:
	; draw F
	; draw integer part
	
	WRITE_SERIAL_FITOA	data_buffer
	WRITE_SERIAL_FITOA	data_buffer + 1
	WRITE_SERIAL_FITOA	data_buffer + 2
	WRITE_SERIAL_FITOA	data_buffer + 3
	WRITE_SERIAL_FITOA	data_buffer + 4
	WRITE_SERIAL_FITOA	data_buffer + 5
	WRITE_SERIAL_FITOA	data_buffer + 6
	WRITE_SERIAL_FITOA	data_buffer + 7
	WRITE_SERIAL_L		' '
	WRITE_SERIAL_F		data_unit
	
	CMP_lf	'M', data_unit
	BR_EQ	MAIN_ALT_Meter
	CMP_lf	'F', data_unit
	BR_EQ	MAIN_ALT_Feet	
	GOTO	MAIN_ALT_draw
	
MAIN_ALT_Meter:	; received unit is Meter
	BTFSS	AU_Select	; if requested unit is meter check range and draw
	GOTO	MAIN_ALT_Meter_format
	;convert to feet
	; 3.281ft / m
	; F = M * 33 / 10
	; convert to u_int_16
	; mult 33
	; convert to bcd
	; unpack bcd to byte, place end_marker before last bcd nibble (0.1th) or fake dot before last bcd nibble
	
	
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
	WRITE_SERIAL_L	'L'
	WRITE_SERIAL_L	'A'
	WRITE_SERIAL_L	'T'
	
	GOTO	ErrorCheck1



;#############################################################################
;	Longitude display 
;#############################################################################

MAIN_LONG:
	WRITE_SERIAL_L	'L'
	WRITE_SERIAL_L	'O'
	WRITE_SERIAL_L	'N'
	
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
	MOVLW	_char_dot
	INCF	NixieDemoCount, F
	BTFSC	NixieDemoCount, 0
	MOVLW	_char_topdot
	WRITE_NIXIE_W	0
	RETURN
	
;#############################################################################
;	Serial TX
;#############################################################################

; convert 0-9 value to ascii '0' to '1' bnefore sending
Serial_TX_write_ITOA:
	MOVLW	'0'
	ADDWF	Serial_Data, F
	
; block wait for availble space in the TX buffer then write the byte
Serial_TX_write:
	;BSF	TX_green
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
	BANK1_0
	
	WRITEp	Serial_Data, Serial_TX_buffer_wp	
	MOV	TX_Temp, Serial_TX_buffer_wp

	BANK0_1
	BSF	PIE1, TXIE	; enable tx interrupts	
	BANK1_0
	RETURN



;#############################################################################
;	Serial RX
;#############################################################################

; block wait for availble data then read RX buffer
Serial_RX_waitRead:
	BSF	WaitRX_red
	CMP_ff	Serial_RX_buffer_wp, Serial_RX_buffer_rp
	BR_EQ	Serial_RX_waitRead
	READp	Serial_RX_buffer_rp, Serial_Data
	INCF	Serial_RX_buffer_rp, F
	BCF	WaitRX_red
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
	
	MOVLW	'0'
	SUBWF	data_H10, F
	SUBWF	data_H01, F
	SUBWF	data_m10, F
	SUBWF	data_m01, F
	SUBWF	data_s10, F
	SUBWF	data_s01, F
	
	RETLW	TRUE



; $GPGGA,205647.91,          , ,           , ,0,00,99.99,   , ,     , ,,*6C
; $GPGGA,205654.00,4538.10504,N,07318.08944,W,1,05,5.36,39.6,M,-32.4,M,,*59
; $GPGGA,  time   , lat      ,N, lat       ,W,x,x , x  , ALT,U
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

; Convert byte to hex and send over serial
WriteHex:
	MOVLW	high (TABLE0)
	MOVWF	PCLATH
	SWAPF	ByteToConvert, W
	ANDLW	0x0F
	CALL	NibbleHex
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	MOVF	ByteToConvert, W
	ANDLW	0x0F
	CALL	NibbleHex
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	MOVLW	' '
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	RETURN
	
;#############################################################################
;	Tables
;#############################################################################

	PC0x0100ALIGN	TABLE0	; set the label and align to next 256 byte boundary in program memory
	
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
	
DIV88:	; D88_Fract = D88_Num / D88_Denum, D88_Num = D88_Num % D88_Denum 
	CLRF	D88_Fract
	
	MOVF	D88_Denum, F	; return if Denum is 0
	BTFSC	STATUS, Z
	RETURN
	
	STR	0x01, D88_Modulo
	BTFSC	D88_Denum, 7
	GOTO	_div88Loop
	
_div88Prep:
	BCF	STATUS, C
	RLF	D88_Denum, F
	BCF	STATUS, C
	RLF	D88_Modulo, F
	BTFSS	D88_Denum, 7
	GOTO	_div88Prep
	
_div88Loop:
	SUB	D88_Num, D88_Denum
	BR_GT	_div88pos
	BR_LT	_div88neg
;if equal
	ADD	D88_Fract, D88_Modulo
	RETURN
_div88pos:
	ADD	D88_Fract, D88_Modulo
	GOTO	_div88roll
_div88neg:
	ADD	D88_Num, D88_Denum
_div88roll:
	BCF	STATUS, C
	RRF	D88_Denum, F
	BCF	STATUS, C
	RRF	D88_Modulo, F
	BTFSS	STATUS, C
	GOTO	_div88Loop	

	RETURN
	
	
	
	
DIV1616:; D88_Fract = D88_Num / D88_Denum, D88_Num = D88_Num % D88_Denum
	CLRFs	D88_Fract

	TESTs	D88_Denum	; return if Denum is 0
	SK_NZ
	RETURN

_DIV1616_start:	
	STRs	0x0001, D88_Modulo
	
	BTFSCs	D88_Denum, 15
	GOTO	_DIV1616_loop
	
_DIV1616_preShift:
	BCF	STATUS, C
	RLFs	D88_Denum
	BCF	STATUS, C
	RLFs	D88_Modulo
	BTFSSs	D88_Denum, 15
	GOTO	_DIV1616_preShift
	
_DIV1616_loop:
	SUBs	D88_Num, D88_Denum
	BR_GT	_DIV1616_pos
	BR_LT	_DIV1616_neg
;if equal
	ADDs	D88_Fract, D88_Modulo
	RETURN
_DIV1616_pos:
	ADDs	D88_Fract, D88_Modulo
	GOTO	_DIV1616_roll
_DIV1616_neg:
	ADDs	D88_Num, D88_Denum
_DIV1616_roll:
	BCF	STATUS, C
	RRFs	D88_Denum
	BCF	STATUS, C
	RRFs	D88_Modulo
	BTFSS	STATUS, C
	GOTO	_DIV1616_loop	

	RETURN
	
DIV8:	; D88_Num = D88_Num / 8, D88_Modulo = D88_Num % 8 
	CLRF	D88_Modulo
	
	BCF	STATUS, C	; / 2
	RRF	D88_Num, F
	RRF	D88_Modulo, F
	
	BCF	STATUS, C	; / 4
	RRF	D88_Num, F
	RRF	D88_Modulo, F
	
	BCF	STATUS, C	; / 8
	RRF	D88_Num, F
	RRF	D88_Modulo, F
	
	BCF	STATUS, C	; shift modulo 1 more time to align with nibble
	RRF	D88_Modulo, F
	SWAPF	D88_Modulo, F

	;dest = a DIV b
	
	; check if b is Zero
	; SCRATCH = 0x01
	; check if MSB if b is 1, else
	; RLF b et SCRATCH until MSB(b) == 1
	
	; TEMP = a
	; TEMP = TEMP - b
	; IF POS
	;   dest += SCRATCH
	;   a = TEMP
	; RRF b et SCRATCH until SCRATCH == 0 (ou le LSB se trouve dans le CARRY)


DIV10:
	MOV	D88_Num, D88_Modulo
	CLRF	D88_Num

	MOVLW	b'10100000'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 4
	SK_NB
	ADDWF	D88_Modulo, F

	MOVLW	b'01010000'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 3
	SK_NB
	ADDWF	D88_Modulo, F

	MOVLW	b'00101000'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 2
	SK_NB
	ADDWF	D88_Modulo, F

	MOVLW	b'00010100'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 1
	SK_NB
	ADDWF	D88_Modulo, F

	MOVLW	b'00001010'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 0
	SK_NB			; could be removed if modulo is not used
	ADDWF	D88_Modulo, F	; could be removed if modulo is not used
	RETURN
	
; 10 = 0000 1010

; div  1010 0000
; ind  0001 0000

; div  0101 0000
; ind  0000 1000

; div  0010 1000
; ind  0000 0100

; div  0001 0100
; ind  0000 0010

; div  0000 1010
; ind  0000 0001

; 33 = 1 + 32
; 2 4 8 16 32
MULT33	MACRO	a, dest

	MOVF	a, W
	MOVWF	dest
	MOVF	a + 1, W
	MOVWF	dest + 1	; dest = a
	
	MOVLW	b'00000111'	; to avoid the rotated-out MSB contaminating the carry bit
	ANDWF	a + 1, F
	
	BCF	STATUS, C
	RLF	a, F
	RLF	a + 1, F 	; a = a * 2
	
	RLF	a, F
	RLF	a + 1, F	; a = a * 4
	
	RLF	a, F
	RLF	a + 1, F	; a = a * 8
	
	RLF	a, F
	RLF	a + 1, F	; a = a * 16
	
	RLF	a, F
	RLF	a + 1, F	; a = a * 32
	
	MOVF	a, W
	ADDWF	dest, F
	SK_NC
	INCF	dest + 1, F	
	MOVF	a + 1, W
	ADDWF	dest + 1, F	; dest = a + 32*a = 33*a

	ENDM
	
MULT10	MACRO	a, dest
	BCF	STATUS, C
	RLF	a, F
	RLF	a + 1, F	; *2
	
	MOVF	a, W 
	MOVWF	dest
	MOVF	a + 1, W
	MOVWF	dest + 1
	
	BCF	STATUS, C
	RLF	a, F
	RLF	a + 1, F	; *4
	BCF	STATUS, C
	RLF	a, F
	RLF	a + 1, F	; *8
	
	MOVF	a, W 
	ADDWF	dest, F
	SK_NC
	INCF	dest, F
	MOVF	a + 1, W
	ADDWF	dest + 1, F	; dest = 2*a + 8*a
	ENDM


; 33 =	00100001
; shift2
;	10000100
;	00000100

;	01000010
;	00000010

;	00100001
;	00000001
	
DIV33:
	MOV	D88_Num, D88_Modulo
	CLRF	D88_Num

	MOVLW	b'10000100'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 2
	SK_NB
	ADDWF	D88_Modulo, F

	MOVLW	b'01000010'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 1
	SK_NB
	ADDWF	D88_Modulo, F

	MOVLW	b'00100001'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 0
	SK_NB			; could be removed if modulo is not used
	ADDWF	D88_Modulo, F	; could be removed if modulo is not used
	RETURN



;#############################################################################
;	Delay routines	
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
	GOTO	WAIT_1s_loop3	; (2) 
	NOP				; (1) 
	
	NOP				; (1) 
	DECFSZ	WAIT_loopCounter2, F	; (1) 
	GOTO	WAIT_1s_loop2		; (2) 	
	
	DECFSZ	WAIT_loopCounter1, F
	GOTO	WAIT_1s_loop1
	RETURN



WAIT_05s:
	MOVLW	10
	MOVWF	WAIT_loopCounter1
	
WAIT_05s_loop1:
	MOVLW	200			; (1) for 100 ms
	MOVWF	WAIT_loopCounter2	; (1)

WAIT_05s_loop2:			; 0.5ms / loop1
	MOVLW	250 - 2			; (1) 250 loops of 4 cycles (minus 2 loop for setup and next loop) 
	MOVWF	WAIT_loopCounter3	; (1) 
	NOP				; (1) 
	NOP				; (1) 

WAIT_05s_loop3:			; 4 cycles per loop (2us / loop2)
	NOP				; (1) 
	DECFSZ	WAIT_loopCounter3, F	; (1) 
	GOTO	WAIT_05s_loop3	; (2) 
	NOP				; (1) 
	
	NOP				; (1) 
	DECFSZ	WAIT_loopCounter2, F	; (1) 
	GOTO	WAIT_05s_loop2		; (2) 	
	
	DECFSZ	WAIT_loopCounter1, F
	GOTO	WAIT_05s_loop1
	RETURN



WAIT_25ms:				; (2) call
	MOVLW	50			; (1) for 25 ms
	MOVWF	WAIT_loopCounter1	; (1)

WAIT_25ms_loop1:			; 0.5ms / loop1
	MOVLW	250 - 1			; (1) 250 loops of 4 cycles (minus 1 loop for setup) 
	MOVWF	WAIT_loopCounter2	; (1) 
	NOP				; (1) 
	NOP				; (1) 

WAIT_25ms_loop2:			; 4 cycles per loop (2us / loop2)
	NOP				; (1) 
	DECFSZ	WAIT_loopCounter2, F	; (1) 
	GOTO	WAIT_25ms_loop2	; (2) 
	NOP				; (1) 
	
	NOP				; (1) 
	DECFSZ	WAIT_loopCounter1, F	; (1) 
	GOTO	WAIT_25ms_loop1	; (2) 
	
	RETURN				; (2)



; at 8MHz, each instruction is 0.5 us
WAIT_01ms:				; call 2 cycle
	MOVLW	50 - 2			; (1) 50 loops of 4 cycles (minus 2 loops for call, setup and return) 
	MOVWF	WAIT_loopCounter1	; (1) 
	NOP				; (1) 
	NOP				; (1) 
					; setup is 4 cycles
WAIT_01ms_loop1:			; 4 cycles per loop
	NOP				; (1) 
	DECFSZ	WAIT_loopCounter1, F	; (1) 
	GOTO	WAIT_01ms_loop1	; (2) 
	NOP
	RETURN				; return 2 cycles



;#############################################################################
;	End Declaration
;#############################################################################

	END
