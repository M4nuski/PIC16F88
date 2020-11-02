;#############################################################################
;	Nixie GPS 1 - (UART Test 5)
;	GPS Time: read, parse, adjust timezone, display
;#############################################################################

	LIST	p=16F88			; processor model
#INCLUDE	<P16F88.INC>		; processor specific variable definitions
#INCLUDE	<PIC16F88_Macro.asm>	; base macro for banks, context, branchs

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
; pin  2 IOA PORTA3	?I AU_select 0=M 1=Ft
; pin  3 IOA PORTA4	I TZ_select 0=-5 (EST) 1=-4 (EDT)
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O WaitRX_red
; pin  7 IO_ PORTB1	
; pin  8 IOR PORTB2	I RX from GPS
; pin  9 IO_ PORTB3	

; pin 10 IO_ PORTB4	
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

#DEFINE TZ_Select		PORTA, 4

#DEFINE WaitRX_red 		PORTB, 0

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

data_H10		EQU	0x29
data_H01		EQU	0x2A
data_m10		EQU	0x2B
data_m01		EQU	0x2C
data_s10		EQU	0x2D
data_s01		EQU	0x2E

NixieVarX		EQU	0x59 ; inner data
NixieVarY		EQU	0x5A ; inner data
NixieLoop		EQU	0x5B ; inner data
NixieSeg		EQU	0x5C ; to pass data between routines
NixieData		EQU	0x5D ; to pass data between routines
NixieTube		EQU	0x5E ; to pass data between routines
NixieDemoCount		EQU	0x5F ; global for demo

D88_Num			EQU	0x60 ; numerator for div and receive modulo (remainder)
D88_Denum		EQU	0x61 ; denumerator for div
D88_Fract		EQU	0x62 ; Receive fraction of div
D88_Modulo		EQU	0x63

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

NixieBuffer				EQU	0xE0 ; to 0xE9, 10 bytes, 80 bit

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
	
BClear	MACRO	file, bit
	LOCAL	_set
	MOVLW	0xFE	;1111 1110 
	BTFSC	bit, 2	;4
	MOVLW	0xEF	;1110 1111
	MOVWF	SCRATCH
	BSF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_set
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_set:
	MOVF	SCRATCH, W
	ANDWF	file, F
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
	CLRF	TRISB		; all outputs	
	BSF	TRISB, 2	; Bit2 is input (RX)
	
	; init analog inputs
	CLRF	ANSEL		; all digital
	
	; init osc 8MHz
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
	; init AUSART	
	; transmitter
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
	
	; receiver
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

;welcome message
	CALL	WAIT_1s	
	
	PC0x0100ALIGN		startUpMessage
	WRITESTRING_LN		"Nixie 1 - Time"
	
	CLRF	PORTA
	CLRF	PORTB
	CLRF	NixieDemoCount
	
; enable interrupts
	BSF	INTCON, PEIE ; peripheral int
	BSF	INTCON, GIE  ; global int


;#############################################################################
;	Main Loop	
;#############################################################################


	
LOOP:
	;GOTO	DEMO

	CALL	READ_NEXT_TIME
	BW_False	NO_TIME
	
	MOV	data_H10, Serial_Data
	CALL	Serial_TX_write
	MOV	data_H01, Serial_Data
	CALL	Serial_TX_write
	
	STR	':', Serial_Data
	CALL 	Serial_TX_write
	
	MOV	data_m10, Serial_Data
	CALL	Serial_TX_write
	MOV	data_m01, Serial_Data
	CALL	Serial_TX_write
	
	STR	':', Serial_Data
	CALL 	Serial_TX_write
	
	MOV	data_s10, Serial_Data
	CALL	Serial_TX_write
	MOV	data_s01, Serial_Data
	CALL	Serial_TX_write
	
	STR	'Z', Serial_Data
	CALL 	Serial_TX_write
	
	STR	' ', Serial_Data
	CALL 	Serial_TX_write
	
	
	MOVLW	5
	BTFSC	TZ_Select
	MOVLW	4
	MOVWF	TZ_offset
	
	CALL	ADJUST_TZ	
	
	MOV	data_H10, Serial_Data
	CALL	Serial_TX_write
	MOV	data_H01, Serial_Data
	CALL	Serial_TX_write
	
	STR	':', Serial_Data
	CALL 	Serial_TX_write
	
	MOV	data_m10, Serial_Data
	CALL	Serial_TX_write
	MOV	data_m01, Serial_Data
	CALL	Serial_TX_write
	
	STR	':', Serial_Data
	CALL 	Serial_TX_write
	
	MOV	data_s10, Serial_Data
	CALL	Serial_TX_write
	MOV	data_s01, Serial_Data
	CALL	Serial_TX_write
	
	STR	'E', Serial_Data
	CALL 	Serial_TX_write
	
	MOVLW	'S'
	BTFSC	TZ_select
	MOVLW	'D'
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	
	STR	'T', Serial_Data
	CALL 	Serial_TX_write
	
	GOTO	ErrorCheck1	
	
	PC0x0100ALIGN		NO_TIME
	WRITESTRING_LN		"No Time Data!"
	
ErrorCheck1:
	BTFBC	Serial_Status, _Serial_bit_RX_overrunError, ErrorCheck2
	STR	' ', Serial_Data
	CALL 	Serial_TX_write
	STR	'O', Serial_Data
	CALL 	Serial_TX_write
	STR	'E', Serial_Data
	CALL 	Serial_TX_write
	STR	'R', Serial_Data
	CALL 	Serial_TX_write
	
ErrorCheck2:
	BTFBC	Serial_Status, _Serial_bit_RX_frameError, ErrorCheck3
	STR	' ', Serial_Data
	CALL 	Serial_TX_write
	STR	'F', Serial_Data
	CALL 	Serial_TX_write
	STR	'E', Serial_Data
	CALL 	Serial_TX_write
	STR	'R', Serial_Data
	CALL 	Serial_TX_write
	
ErrorCheck3:
	BTFBC	Serial_Status, _Serial_bit_RX_bufferOverrun, ErrorCheck_End
	STR	' ', Serial_Data
	CALL 	Serial_TX_write
	STR	'R', Serial_Data
	CALL 	Serial_TX_write
	STR	'B', Serial_Data
	CALL 	Serial_TX_write
	STR	'E', Serial_Data
	CALL 	Serial_TX_write
	STR	'R', Serial_Data
	CALL 	Serial_TX_write
	
ErrorCheck_End:
	CALL	WriteEOL
	CLRF	Serial_Status	
	
	
	
DEMO:
	;CALL	Wait_05s
; Write data to Nixie tubes
	;INCF	NixieDemoCount, F
	;CMP_lf	9, NixieDemoCount
	;SK_NE	
	;CLRF	NixieDemoCount
	
	CALL	Nixie_None	
	
	STR	2, NixieTube
	MOVLW	'0'
	SUBWF	data_H10, W
	MOVWF	NixieData
	CALL	Nixie_DrawNum
		
	STR	3, NixieTube
	MOVLW	'0'
	SUBWF	data_H01, W
	MOVWF	NixieData
	CALL	Nixie_DrawNum	
	
	
	STR	5, NixieTube
	MOVLW	'0'
	SUBWF	data_m10, W
	MOVWF	NixieData
	CALL	Nixie_DrawNum
	
	STR	6, NixieTube
	MOVLW	'0'
	SUBWF	data_m01, W
	MOVWF	NixieData
	CALL	Nixie_DrawNum
	
	
	STR	8, NixieTube
	MOVLW	'0'
	SUBWF	data_s10, W
	MOVWF	NixieData
	CALL	Nixie_DrawNum
	
	STR	9, NixieTube
	MOVLW	'0'
	SUBWF	data_s01, W
	MOVWF	NixieData
	CALL	Nixie_DrawNum
	
	
	;MOV	NixieDemoCount, NixieData
	
	;STR	1, NixieTube
	;CALL	Nixie_DrawNum	; light up 1 segment, seg# in NixieData, tube# in NixieTube

	;STR	2, NixieTube
	;CALL	Nixie_DrawNum

	;STR	3, NixieTube
	;CALL	Nixie_DrawNum
	

	;STR	5, NixieTube
	;CALL	Nixie_DrawNum

	;STR	6, NixieTube
	;CALL	Nixie_DrawNum

	;STR	7, NixieTube
	;CALL	Nixie_DrawNum

	;STR	8, NixieTube
	;CALL	Nixie_DrawNum

	;STR	9, NixieTube
	;CALL	Nixie_DrawNum
	

	;BCF	STATUS, C
	;RRF	NixieData, W
	;MOVWF	NixieSeg
	;STR	0, NixieTube
	;CALL	Nixie_SetSegment
	
	;STR	4, NixieTube
	;CALL	Nixie_SetSegment

	
	CALL	Nixie_Send
	
;	CALL	Nixie_None
;	MOVLW	NixieBuffer
;	ADDWF	NixieDemoCount, W
;	MOVWF	FSR
;	CLRF	INDF
;	CALL	Nixie_Send

; flash all on/off
;	BTFSC	NixieDemoCount, 0
;	GOTO	NixieDemoAll
;	GOTO	NixieDemoNone
;NixieDemoAll:
;	CALL	Nixie_All
;	CALL	Nixie_Send	
;	GOTO	LOOP
;NixieDemoNone:
;	CALL	Nixie_None
;	CALL	Nixie_Send
;	GOTO	LOOP

	
	GOTO	LOOP

;#############################################################################
;	Subroutines
;#############################################################################


	
;#############################################################################
;	Serial TX
;#############################################################################

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

Nixie_DrawChar:	; Draw char [.:+-ecmfa], char code in NixieData, tube in NixieTube

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

; $GPGGA,205654.00,
READ_NEXT_TIME:
	CALL	Serial_RX_waitRead
	CMP_lf	'$', Serial_Data
	BR_NE	READ_NEXT_TIME
	
	CALL	Serial_RX_waitRead
	CMP_lf	'G', Serial_Data
	BR_NE	READ_NEXT_TIME

	CALL	Serial_RX_waitRead
	CMP_lf	'P', Serial_Data
	BR_NE	READ_NEXT_TIME
	
	CALL	Serial_RX_waitRead
	CMP_lf	'G', Serial_Data
	BR_NE	READ_NEXT_TIME
	
	CALL	Serial_RX_waitRead
	CMP_lf	'G', Serial_Data
	BR_NE	READ_NEXT_TIME
	
	CALL	Serial_RX_waitRead
	CMP_lf	'A', Serial_Data
	BR_NE	READ_NEXT_TIME
	
	CALL	Serial_RX_waitRead
	CMP_lf	',', Serial_Data
	BR_NE	READ_NEXT_TIME	
	
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
	
	RETLW	TRUE
	
;#############################################################################
;	Timezone adjust
;#############################################################################

ADJUST_TZ:
	; adjust timezone
	SUBL	data_H01, '0'; ascii to int
	SUBL	data_H10, '0'; ascii to int
	
	BCF	STATUS, C
	RLF	data_H10, F ; h10  = 2*h10
	MOVF	data_H10, W ; w = 2*h10
	BCF	STATUS, C
	RLF	data_H10, F ; h10  = 4*h10
	RLF	data_H10, F ; h10  = 8*h10
	ADDWF	data_H10, W
	
	ADDWF	data_H01, F ; h01 = 10*h10 + h01 = HH(utc)
	
	SUB	data_H01, TZ_offset ; h01 = HH(EDT/EST)
	BR_NB	ADJUST_TZ_DONE_NB
	ADDL	data_H01, 24
ADJUST_TZ_DONE_NB:
	CLRF	data_H10
	CMP_lf	10, data_H01
	BR_GT	ADJUST_TZ_DONE
	INCF	data_H10, F
	SUBL	data_H01, 10

	CMP_lf	10, data_H01
	BR_GT	ADJUST_TZ_DONE
	INCF	data_H10, F
	SUBL	data_H01, 10
ADJUST_TZ_DONE:		
	ADDL	data_H01, '0'
	ADDL	data_H10, '0'		
	RETURN



;#############################################################################
;	Serial formatting and helpers
;#############################################################################
	
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
	
WriteSpace:
	MOVLW	' '
	MOVWF	Serial_Data
	CALL 	Serial_TX_write	
	RETURN
WriteEOL:
	MOVLW	13		;(CR)
	MOVWF	Serial_Data
	CALL 	Serial_TX_write	
	MOVLW	10		;(LF)
	MOVWF	Serial_Data
	CALL 	Serial_TX_write
	RETURN

;#############################################################################
;	Tables
;#############################################################################

	PC0x0100ALIGN	TABLE0	
	
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
	
Nixie_Char_seg0_7:
	; a -> HBar
	; b -> TDot
	; c -> BDot
	; d -> VBar
	ADDWF	PCL, F
	   ;     'hgfedcba'
	RETLW	b'00110101' ;.
	RETLW	b'00000000' ;:
	RETLW	b'01110110' ;-
	RETLW	b'11110100' ;+
	RETLW	b'01001000' ;E
	RETLW	b'10111100' ;C
	RETLW	b'10110111' ;F
	RETLW	b'00000100' ;M
	RETLW	b'11111110' ;
	RETLW	b'01001100' ;
	
Nixie_Char_seg8:
	ADDWF	PCL, F
	    ;    '       i'
	RETLW	b'00000001' ;.
	RETLW	b'00000001' ;:
	RETLW	b'00000000' ;-
	RETLW	b'00000000' ;+
	RETLW	b'00000001' ;E
	RETLW	b'00000000' ;C
	RETLW	b'00000000' ;F
	RETLW	b'00000001' ;M
	RETLW	b'00000000' ;
	RETLW	b'00000001' ;
	
DIV88:	; D88_Fract = D88_Num / D88_Denum, D88_Num = D88_Num % D88_Denum 
	CLRF	D88_Fract
	
	MOVF	D88_Denum, F	; return if Denum is 0
	BTFSC	STATUS, Z
	RETURN
	
	STR	0x01, SCRATCH	; index
	BTFSC	D88_Denum, 7
	GOTO	_div88Loop
	
_div88Prep:
	BCF	STATUS, C
	RLF	D88_Denum, F
	BCF	STATUS, C
	RLF	SCRATCH, F
	BTFSS	D88_Denum, 7
	GOTO	_div88Prep
	
_div88Loop:
	SUB	D88_Num, D88_Denum
	BR_GT	_div88pos
	BR_LT	_div88neg
;if equal
	ADD	D88_Fract, SCRATCH
	RETURN
_div88pos:
	ADD	D88_Fract, SCRATCH
	GOTO	_div88roll
_div88neg:
	ADD	D88_Num, D88_Denum
_div88roll:
	BCF	STATUS, C
	RRF	D88_Denum, F
	BCF	STATUS, C
	RRF	SCRATCH, F
	BTFSS	STATUS, C
	GOTO	_div88Loop	

	RETURN
	
D8:	; D88_Num = D88_Num / 8, D88_Modulo = D88_Num % 8 
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
