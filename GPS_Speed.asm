;#############################################################################
;	GPS Speed display 1
;	7 segments display of GPS speed data in KM/H trough 74LS47
;	4 digits, 000.0 to 999.9
;	could be used to implement climb rate
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
; pin  1 IOA PORTA2	O BCD bit 2 
; pin  2 IOA PORTA3	O BCD bit 3
; pin  3 IOA PORTA4	O Status bit ISR
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O Digit select 0
; pin  7 IO_ PORTB1	O Digit select 1
; pin  8 IOR PORTB2	I RX from GPS
; pin  9 IO_ PORTB3	O Digit select 2

; pin 10 IO_ PORTB4	O Digit select 3
; pin 11 IOT PORTB5	O TX to computer
; pin 12 IOA PORTB6	I ICSP PGC
; pin 13 IOA PORTB7	I ICSP PGD
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O status bit Loop
; pin 16 I_X PORTA7	I debug info through uart.
; pin 17 IOA PORTA0	O BCD bit 0
; pin 18 IOA PORTA1	O BCD bit 1


#DEFINE DigitSelect0		PORTB, 0
#DEFINE DigitSelect1		PORTB, 1
#DEFINE DigitSelect2		PORTB, 3
#DEFINE DigitSelect3		PORTB, 4

#DEFINE StatusBit_ISR		PORTA, 4
#DEFINE StatusBit_Loop	PORTA, 6

#DEFINE DebugInfoBit		PORTA, 7

#DEFINE	END_MARKER		0xFF
#DEFINE	CONV_DOT		'.' - '0'
#DEFINE	CONV_MINUS		'-' - '0'

#DEFINE	SERIAL_DEBUG

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
;			EQU	0x26
dot_offset		EQU	0x27 ; 
WriteLoop		EQU	0x28 ; for NixieSerial and WriteString
TX_Temp			EQU	0x29 ; for RX/TX buffer address calculation

data_buffer		EQU	0x2A ; 0x2A to 0x3E -> 20 bytes


; 4538.10504,N
;data_latD10			EQU	0x2A
;data_latD01			EQU	0x2B
;data_latM10			EQU	0x2C
;data_latM01			EQU	0x2D
;data_latDot			EQU	0x2E
;data_latFract			EQU	0x2F

; 07318.08944,W
;data_longD100			EQU	0x2A
;data_longD010			EQU	0x2B
;data_longD001			EQU	0x2C
;data_longM10			EQU	0x2D
;data_longM01			EQU	0x2E
;data_longDot			EQU	0x2F
;data_longFract			EQU	0x30

;			EQU	0x3E ; last byte of data_buffer

BCD_Result		EQU	0x3F ; 0x40 0x41 0x42 for 8 bcd nibbles, up to 16 77 72 15 (24 bit to bcd)
D88_Fract		EQU	0x43 ; 0x44 0x45 resulting fraction of div
D88_Modulo		EQU	0x46 ; 0x47 0x48 Modulo for preset div, also index for arbitrary div
D88_Num			EQU	0x49 ; 0x4A 0x4B 0x4C numerator for div and receive modulo (remainder)
D88_Denum		EQU	0x4D ; 0x4E 0x4F 0x50 denumerator for div
DigitCount		EQU	0x51
;_mode_Time				EQU	0
;_mode_Alt				EQU	1
;_mode_Lat				EQU	2
;_mode_Long				EQU	3
IntToConvert		EQU	0x52 ; 0x53 0x54 0x55 for convert to hex or BCD

;			EQU	0x56
;			EQU	0x57
;			EQU	0x58

NixieVarX		EQU	0x59 ; local var
NixieVarY		EQU	0x5A ; loval var
NixieLoop		EQU	0x5B ; local var
;NixieSeg		EQU	0x5C ; to pass data between routines
;NixieData		EQU	0x5D ; to pass data between routines
;NixieTube		EQU	0x5E ; to pass data between routines
;NixieDemoCount	EQU	0x5F ; global for demo and "no data" display

Digit0			EQU	0x60 ; 100
Digit1			EQU	0x61 ; 10
Digit2			EQU	0x62 ; 1
Digit3			EQU	0x63 ; 1/10th km/h

;			EQU	0x64
;			EQU	0x65
;			EQU	0x66
;			EQU	0x67

;			EQU	0x68
;			EQU	0x69
;			EQU	0x6A
;			EQU	0x6B

;			EQU	0x6C

; GPR files in GPR for context saving from PIC16f88_Macro.asm
;STACK_FSR		EQU	0x6D
;STACK_SCRATCH		EQU	0x6E
;STACK_PCLATH		EQU	0x6F

; Bank 1

_Serial_RX_buffer_startAddress	EQU	0xA0 ; circular RX buffer start
_Serial_RX_buffer_endAddress		EQU	0xC0 ; circular RX buffer end + 1

_Serial_TX_buffer_startAddress	EQU	0xC0 ; circular TX buffer start
_Serial_TX_buffer_endAddress		EQU	0xE0 ; circular TX buffer end + 1

;NixieBuffer		EQU	0xE0 ; to 0xE9, 10 bytes, 80 bit

;			EQU	0xEA
;			EQU	0xEB
;			EQU	0xEC

;			EQU	0xED
;			EQU	0xEE
;			EQU	0xEF

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

; GPR files in shared GPR for instruction extensions from PIC16f88_Macro.asm
;SCRATCH		EQU	0x7D

; GPR files in shared GPR for context saving from PIC16f88_Macro.asm
;STACK_STATUS		EQU	0x7E
;STACK_W		EQU	0x7F


; GPVTG csv data indices $GPVTG,,T,,M,0.046,N,0.085,K,A*2C
_index_Speed	EQU 6


;#############################################################################
;	MACRO
;#############################################################################

WRITESTRING_LN	MACRO string
	LOCAL	_END, _TABLE, _NEXT
	
	IF 	( _END & 0xFFFFFF00 ) != ( $ & 0xFFFFFF00 )
	ORG	( $ & 0xFFFFFF00 ) + 0x0100
	ENDIF	; boundary check
	
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
	
	BSF	StatusBit_ISR

	BTFBS	PIR1, TMR1IF, ISR_T1
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
	GOTO	ISR_END
	
	
ISR_T1:
	BCF	PIR1, TMR1IF

	STR	b'11110000', TMR1H

	;reset digit selection
	BSF	DigitSelect0
	BSF	DigitSelect1
	BSF	DigitSelect2
	BSF	DigitSelect3	
	
	CMP_LF	0, DigitCount
	BR_EQ	ISR_T1_0
	CMP_LF	1, DigitCount
	BR_EQ	ISR_T1_1
	CMP_LF	2, DigitCount
	BR_EQ	ISR_T1_2
	CMP_LF	3, DigitCount
	BR_EQ	ISR_T1_3
	
	;BCF	DigitSelect0
	;BCF	DigitSelect1
	;BCF	DigitSelect2
	;BCF	DigitSelect3
	GOTO	ISR_END
	
ISR_T1_0:
	BCF	DigitSelect0
	MOVF	Digit0, W
	MOVWF	PORTA
	GOTO	ISR_T1b
	
ISR_T1_1:
	BCF	DigitSelect1
	MOVF	Digit1, W
	MOVWF	PORTA
	GOTO	ISR_T1b
	
ISR_T1_2:
	BCF	DigitSelect2
	MOVF	Digit2, W
	MOVWF	PORTA
	GOTO	ISR_T1b
	
ISR_T1_3:
	BCF	DigitSelect3
	MOVF	Digit3, W
	MOVWF	PORTA
	GOTO	ISR_T1b

ISR_T1b:
	INCF	DigitCount, F
	MOVLW	b'00000011'
	ANDWF	DigitCount, F
	
ISR_END:	

	BCF	StatusBit_ISR
	
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
	BSF	DebugInfoBit

	CLRF	TRISB		; all outputs
	BSF	TRISB, 2	; Bit2 is input (RX)


	; init analog inputs
	CLRF	ANSEL		; all digital

	; init osc 8MHz
	BCF	OSCCON, SCS0
	BCF	OSCCON, SCS1
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
SETUP_OSC:
	BTFSS	OSCCON, IOFS
	GOTO	SETUP_OSC

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
	BSF	PIE1, TMR1IE	; enable timer1 interrupts

	BANK0

	; init AUSART receiver
	BSF	RCSTA, SPEN	; serial port enabled
	BCF	RCSTA, RX9	; 8 bit rx
	;BSF	RCSTA, SREN	; not used in async - enable single receive
	BSF	RCSTA, CREN	; enable continuous receive
	BCF	RCSTA, ADDEN	; disable addressing
	
		; at 8x prescaler, 8mhz crystal, 2mhz instruction clock, 3.8hz timer1 overflow
	CLRF	TMR1L
	CLRF	TMR1H
	BCF	T1CON, T1CKPS0	; 
	BCF	T1CON, T1CKPS1	;
	BCF	T1CON, TMR1CS	; timer clock is FOSC/4
	BSF	T1CON, TMR1ON	; timer ON


	; initialize circular buffer pointers
	MOVLW	_Serial_RX_buffer_startAddress
	MOVWF	Serial_RX_buffer_rp
	MOVWF	Serial_RX_buffer_wp

	MOVLW	_Serial_TX_buffer_startAddress
	MOVWF	Serial_TX_buffer_rp
	MOVWF	Serial_TX_buffer_wp

	CLRF	PORTA
	CLRF	PORTB

	CLRF	Serial_Status
	BSF	Serial_Status, _Serial_bit_RX_inhibit
	
	BCF	StatusBit_ISR
	BCF	StatusBit_Loop

; enable interrupts
	BSF	INTCON, PEIE ; peripheral int
	BSF	INTCON, GIE  ; global int
	
	CLRF	DigitCount

	FAR_CALL	WAIT_1s	

	FAR_CALL	WAIT_1s
		
	PC0x0100ALIGN	cmd
cmd:
	MOVLW	high (cmd_TABLE)
	MOVWF	PCLATH
	CLRF	WriteLoop
cmd_NEXT
	MOVF	WriteLoop, W
	CALL 	cmd_TABLE
	SUBLW	0xFF
	BTFSC	STATUS, Z
	GOTO	cmd_END
	MOVF	WriteLoop, W
	CALL 	cmd_TABLE
	MOVWF	Serial_Data
	CALL	Serial_TX_write
	INCF	WriteLoop, F
	GOTO	cmd_NEXT
cmd_TABLE:
	ADDWF	PCL, F
	DT	0xB5, 0x62, 0x06, 0x08, 0x06, 0x00, 0xC8, 0x00, 0x01, 0x00, 0x01, 0x00, 0xDE, 0x6A, 0xB5, 0x62, 0x06, 0x08, 0x00, 0x00, 0x0E, 0x30, 0xFF
cmd_END:


	;FAR_CALL	WAIT_1s
	;WRITESTRING_LN		"GPS Speed 1 - km/h - 2023-06-24"
	;FAR_CALL	WAIT_1s
	;WRITESTRING_LN		"Stalling..."


;#############################################################################
;	Main Loop
;#############################################################################

;B5 62 06 08 06 00 C8 00 01 00 01 00 DE 6A B5 62 06 08 00 00 0E 30 5hz

LOOP:
	BSF	StatusBit_Loop
	
	BTFSS	DebugInfoBit
	GOTO	LOOPa
	IFDEF	SERIAL_DEBUG
	WRITE_SERIAL_L	'D'
	WRITE_SERIAL_L	':'
	WRITE_SERIAL_FITOA	Digit0
	WRITE_SERIAL_FITOA	Digit1
	WRITE_SERIAL_FITOA	Digit2
	WRITE_SERIAL_L		'.'
	WRITE_SERIAL_FITOA	Digit3
	WRITE_SERIAL_L	13		;(CR)
	WRITE_SERIAL_L	10		;(LF)
	ENDIF
	
LOOPa:	
	MOVLW	_index_Speed
	CALL	READ_NEXT	
	BW_False	Draw_No_Data

	; valid data, process digits to display
	
	WRITE_SERIAL_FITOA	data_buffer
	WRITE_SERIAL_FITOA	data_buffer + 1
	WRITE_SERIAL_FITOA	data_buffer + 2
	WRITE_SERIAL_FITOA	data_buffer + 3
	WRITE_SERIAL_FITOA	data_buffer + 4
	WRITE_SERIAL_FITOA	data_buffer + 5
	WRITE_SERIAL_FITOA	data_buffer + 6
	WRITE_SERIAL_FITOA	data_buffer + 7

	WRITE_SERIAL_L	13		;(CR)
	WRITE_SERIAL_L	10		;(LF)
	
	
	
	BCF	StatusBit_Loop
	; reset digits
	MOVLW	0x0F
	MOVWF	Digit0
	MOVWF	Digit1
	MOVWF	Digit2
	MOVWF	Digit3
	

	
	; search for dot
	CLRF	dot_offset
	STR	data_buffer, FSR ;FSR = @data_buffer, INDF = data_buffer[0]
dot_search:
	INCF	dot_offset, F
	INCF	FSR, F
	CMP_LF	7, dot_offset
	BR_EQ	ErrorCheck1		; if dot_offset = 5 bail out to start of LOOP
	CMP_LF	CONV_DOT, INDF	; if data_buffer[dot_offset] != "."
	BR_NE	dot_search	; keep searching
	;CMP_LF	0x10
	;BR_EQ	ErrorCheck1
	; now on dot
	; next is 1/10th kmh value
	INCF	dot_offset, F
	INCF	FSR, F
	MOV	INDF, Digit3
	
	DECF	dot_offset, F
	DECF	FSR, F
	; now back on dot
	
	DECF	dot_offset, F
	DECF	FSR, F
	; now on 1 kmh	
	MOV	INDF, Digit2
	TEST	dot_offset
	BR_ZE	ErrorCheck1
	
	DECF	dot_offset, F
	DECF	FSR, F
	MOV	INDF, Digit1	
	TEST	dot_offset
	BR_ZE	ErrorCheck1	

	DECF	dot_offset, F
	DECF	FSR, F
	MOV	INDF, Digit0
	TEST	dot_offset
	BR_ZE	ErrorCheck1
	
	GOTO	ErrorCheck1

Draw_No_Data:
	BTFSS	DebugInfoBit
	GOTO	LOOPz
	WRITE_SERIAL_L	'N'
	WRITE_SERIAL_L	'D'

;#############################################################################
;	Serial module error check and reporting
;#############################################################################

ErrorCheck1:
	BTFSS	DebugInfoBit
	GOTO	LOOPz
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

LOOPz:
	CLRF	Serial_Status

	GOTO	LOOP
	
;#############################################################################
;	End of main loop
;#############################################################################


;#############################################################################
;	Subroutines
;#############################################################################


;#############################################################################
;	Serial TX
;#############################################################################

; convert 0-9 value to ascii '0' to '9' before sending
Serial_TX_write_ITOA:
	MOVLW	'0'
	ADDWF	Serial_Data, F
; block wait for availble space in the TX buffer then write the byte
Serial_TX_write:
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
	CMP_ff	Serial_RX_buffer_wp, Serial_RX_buffer_rp
	BR_EQ	Serial_RX_waitRead
	READp	Serial_RX_buffer_rp, Serial_Data
	INCF	Serial_RX_buffer_rp, F

	CMP_lf	_Serial_RX_buffer_endAddress, Serial_RX_buffer_rp
	SK_EQ
	RETURN
	STR	_Serial_RX_buffer_startAddress, Serial_RX_buffer_rp
	RETURN


;#############################################################################
;	GPS serial read and parse
;#############################################################################

WAIT_GPVTG_HEADER:
	BCF	Serial_Status, _Serial_bit_RX_inhibit

	CALL	Serial_RX_waitRead
	CMP_lf	'$', Serial_Data
	BR_NE	WAIT_GPVTG_HEADER

	CALL	Serial_RX_waitRead
	CMP_lf	'G', Serial_Data
	BR_NE	WAIT_GPVTG_HEADER

	CALL	Serial_RX_waitRead
	CMP_lf	'P', Serial_Data
	BR_NE	WAIT_GPVTG_HEADER

	CALL	Serial_RX_waitRead
	CMP_lf	'V', Serial_Data
	BR_NE	WAIT_GPVTG_HEADER

	CALL	Serial_RX_waitRead
	CMP_lf	'T', Serial_Data
	BR_NE	WAIT_GPVTG_HEADER

	CALL	Serial_RX_waitRead
	CMP_lf	'G', Serial_Data
	BR_NE	WAIT_GPVTG_HEADER

	CALL	Serial_RX_waitRead
	CMP_lf	',', Serial_Data
	BR_NE	WAIT_GPVTG_HEADER

	RETURN


; read next GPGGA CSV data, requested index is passed in W, index 0 is the time, fetched in READ_NEXT_TIME
READ_NEXT:
	MOVWF	NixieVarX		; save index
	CALL	WAIT_GPVTG_HEADER

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

	RETLW	TRUE







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
	RLFi	BCD_Result
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

	STR	data_buffer, NixieVarY	; Y = @data
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

;	skip leading 0s by bubbling data back to the start of destination
ExpandBCD_trimLeft:
	MOV	NixieVarY, FSR ; start of buffer
	MOVF	INDF, W		; until not 0
	SK_ZE
	RETURN
	CMP_lf	END_MARKER, INDF ; or end marker
	SK_NE
	RETURN

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
	STRc	0x040000, D88_Modulo
	STRc	0x840000, D88_Denum

_DIV33c_loop:
	SUBc	D88_Num, D88_Denum
	BR_GT	_DIV33c_pos
	BR_LT	_DIV33c_neg
;if equal
	ADDc	D88_Fract, D88_Modulo
	RETURN
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
	RETURN

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
	RETURN
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
	RETURN



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
	RETURN


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
	RETURN

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
	RETURN


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
	RETURN


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
	RETURN



;#############################################################################
;	End Declaration
;#############################################################################

	END
