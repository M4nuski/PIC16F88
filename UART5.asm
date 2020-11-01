;#############################################################################
;	UART Test 5
;	Loopback
;	RX/TX Circular buffer
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
WRITESTRING_LN_DIRECT	MACRO string
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
	CALL	Serial_TX_directWrite
	INCF	WriteLoop, F
	GOTO	_NEXT
_TABLE:
	ADDWF	PCL, F
	DT	string, 13, 10, 0
_END:
	ENDM
	
;#############################################################################
;	Pinout
;#############################################################################

; pin  1 IOA PORTA2	O isr_TX_SQgreen
; pin  2 IOA PORTA3	O isr_RX_SQred
; pin  3 IOA PORTA4	I TZ_select 0=-5 (EST) 1=-4 (EDT)
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O WaitRX_red
; pin  7 IO_ PORTB1	O OverrunError_yellow
; pin  8 IOR PORTB2	I RX
; pin  9 IO_ PORTB3	O TX_green

; pin 10 IO_ PORTB4	O FrameError_yellow
; pin 11 IOT PORTB5	O TX
; pin 12 IOA PORTB6	(PGC)
; pin 13 IOA PORTB7	(PGD)
; pin 14 PWR VDD	VCC
; pin 15 _O_ PORTA6	XT
; pin 16 I__ PORTA7	XT
; pin 17 IOA PORTA0	
; pin 18 IOA PORTA1

#DEFINE isr_TX_SQgreen	PORTA, 2
#DEFINE isr_RX_SQred		PORTA, 3
#DEFINE TZ_Select		PORTA, 4

#DEFINE WaitRX_red 		PORTB, 0
#DEFINE OverrunError_yellow	PORTB, 1
#DEFINE TX_green		PORTB, 3
#DEFINE FrameError_yellow	PORTB, 4

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

WAIT_loopCounter1	EQU	0x20
WAIT_loopCounter2	EQU	0x21
WAIT_loopCounter3	EQU	0x22

Serial_Data		EQU	0x23
Serial_Status		EQU	0x24
_Serial_bit_RX_avail 			EQU	0	;data available in RX buffer
_Serial_bit_RX_bufferFull		EQU	1	;RX buffer is full, next RX will overrun unless read
_Serial_bit_TX_avail 			EQU	2	;space available in TX buffer
_Serial_bit_RX_frameError 		EQU	3	;uart module frame error
_Serial_bit_RX_overrunError 		EQU	4	;uart module overrun error
_Serial_bit_TX_bufferOverrun		EQU	5	;TX circular buffer overrun error
_Serial_bit_RX_bufferOverrun 		EQU	6	;RX circular buffer overrun error

ByteToConvert		EQU	0x25
TZ_offset		EQU	0x26
WriteLoop		EQU	0x27
TX_Temp			EQU	0x28

data_H10		EQU	0x29
data_H01		EQU	0x2A
data_m10		EQU	0x2B
data_m01		EQU	0x2C
data_s10		EQU	0x2D
data_s01		EQU	0x2E

; Bank 1
_Serial_RX_buffer_startAddress	EQU	0xA0 ; circular RX buffer start
_Serial_RX_buffer_endAddress		EQU	0xC0 ; circular RX buffer end

_Serial_TX_buffer_startAddress	EQU	0xC0 ; circular TX buffer start
_Serial_TX_buffer_endAddress		EQU	0xE0 ; circular TX buffer end

;#############################################################################
;	Shared Files 0x70 - 0x7F
;#############################################################################

Serial_RX_buffer_rp	EQU	0x70 ; circular RX buffer read pointer
Serial_RX_buffer_wp	EQU	0x71 ; circular RX buffer write pointer

Serial_TX_buffer_rp	EQU	0x72 ; circular TX buffer read pointer
Serial_TX_buffer_wp	EQU	0x73 ; circular TX buffer write pointer


;SCRATCH	EQU	0x7A
; For ISR context
;STACK_SCRATCH	EQU	0x7B
;STACK_FSR	EQU	0x7C
;STACK_PCLATH	EQU	0x7D
;STACK_STATUS	EQU	0x7E
;STACK_W	EQU	0x7F

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
	
	BSF	isr_RX_SQred
	BSF	isr_TX_SQgreen
	
	GOTO	ISR_END 		; unkown interrupt
	
ISR_RX:
	BSF	isr_RX_SQred	
	
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
	BSF	isr_TX_SQgreen

	CMP_ff	Serial_TX_buffer_rp, Serial_TX_buffer_wp	; check for data to send
	BR_EQ	ISR_TX_empty
	
	READp	Serial_TX_buffer_rp, TXREG		; indirect read buffer and store in ausart register

	INCF	Serial_TX_buffer_rp, F		; move pointer forward
	CMP_lf	_Serial_TX_buffer_endAddress, Serial_TX_buffer_rp
	BR_NE	ISR_END					; warp around if at the end
	STR	_Serial_TX_buffer_startAddress, Serial_TX_buffer_rp
	GOTO	ISR_END
	
ISR_TX_empty:
	BCF	TX_green
	BANK0_1
	BCF	PIE1, TXIE	; disable tx interrupts	
	BANK1_0
	;GOTO	ISR_END

ISR_END:
	BCF	isr_RX_SQred
	BCF	isr_TX_SQgreen
	
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
	
	ORG	( $ & 0xFFFFFF00 ) + 0x100
	WRITESTRING_LN_DIRECT "UART 5"
	
	CLRF	PORTA
	CLRF	PORTB
	
; enable interrupts
	BSF	INTCON, PEIE ; peripheral int
	BSF	INTCON, GIE  ; global int


;#############################################################################
;	Main Loop	
;#############################################################################


	
LOOP:
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
	
	CALL	WriteEOL

	;MOV	PORTA, ByteToConvert
	;CALL	WriteHex
	;CALL	WriteSpace
	;CALL	WriteEOL
	
	
	BCF	OverrunError_yellow
	BTFSC	Serial_Status, _Serial_bit_RX_overrunError
	BSF	OverrunError_yellow
	
	BCF	FrameError_yellow
	BTFSC	Serial_Status, _Serial_bit_RX_frameError
	BSF	FrameError_yellow
	CLRF	Serial_Status
	
	
	GOTO	LOOP
	
	ORG	( $ & 0xFFFFFF00 ) + 0x100
NO_TIME:
	WRITESTRING_LN	"No Time Data!"

	
	GOTO	LOOP

;#############################################################################
;	Subroutines
;#############################################################################


	
;#############################################################################
;	Serial TX
;#############################################################################

; check TX buffer is available, return with TRUE(0) in W if avail, FALSE(1) in W if not
Serial_TX_isByteAvailable:
	INCF	Serial_TX_buffer_wp, W	; calculate next possible write pointer position
	MOVWF	TX_Temp
	CMP_lf	_Serial_TX_buffer_endAddress, TX_Temp
	BR_NE	Serial_TX_isByteAvailable_2
	STR	_Serial_TX_buffer_startAddress, TX_Temp
Serial_TX_isByteAvailable_2:
	CMP_ff	Serial_TX_buffer_rp, TX_Temp	; compare to current read pointer
	SK_EQ
	RETLW	TRUE	; pointers are not equal
	RETLW	FALSE	; both pointers are equal, no place in buffer



; block wait for availble space in the TX buffer then write the byte
Serial_TX_write:
	BSF	TX_green
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



; write a byte to the TX buffer regardless of the available space
Serial_TX_forceWrite:
	BSF	TX_green
	BANK0_1
	BCF	PIE1, TXIE	; disable tx interrupts	
	BANK1_0
	
	WRITEp	Serial_Data, Serial_TX_buffer_wp

	INCF	Serial_TX_buffer_wp, F	; advance pointer
	CMP_lf	_Serial_TX_buffer_endAddress, Serial_TX_buffer_wp	
	BR_NE	Serial_TX_forceWrite_END
	STR	_Serial_TX_buffer_startAddress, Serial_TX_buffer_wp
Serial_TX_forceWrite_END:
	BANK0_1
	BSF	PIE1, TXIE	; enable tx interrupts	
	BANK1_0
	RETURN



; reset TX and buffers
Serial_TX_purge:
	BANK0_1
	BCF	TXSTA, TXEN	; disable tx
	BCF	PIE1, TXIE	; disable tx interrupts
	BANK1_0
	MOVLW	_Serial_TX_buffer_startAddress	;reset buffer pointers
	MOVWF	Serial_TX_buffer_wp
	MOVWF	Serial_TX_buffer_rp
	BANK0_1
	BSF	PIE1, TXIE	; enable tx interrupts
	BSF	TXSTA, TXEN	; enable tx
	BANK1_0
	RETURN



; write data directly to ausart without using interrupts and buffers
Serial_TX_directWrite:
	BANK0_1
	BCF	PIE1, TXIE	; disable tx interrupts
	BANK1_0
	BSF	TX_green
	BTFSS	PIR1, TXIF
	GOTO	Serial_TX_directWrite
	MOVF	Serial_Data, W
	MOVWF	TXREG
	BCF	TX_green	
	RETURN



;#############################################################################
;	Serial RX
;#############################################################################

; check if a RX byte is available, return with TRUE(0) in W if avail, FALSE(1) in W if not
Serial_RX_isByteAvailable:
	CMP_ff	Serial_RX_buffer_wp, Serial_RX_buffer_rp
	SK_EQ
	RETLW	TRUE	; pointers are not equal
	RETLW	FALSE	; both pointers are equal



; block wait for available data in RX buffer
Serial_RX_wait:
	BSF	WaitRX_red
	CMP_ff	Serial_RX_buffer_wp, Serial_RX_buffer_rp
	BR_EQ	Serial_RX_wait	
	BCF	WaitRX_red
	RETURN



; read next data in RX buffer
Serial_RX_read:
	READp	Serial_RX_buffer_rp, Serial_Data
	INCF	Serial_RX_buffer_rp, F
	CMP_lf	_Serial_RX_buffer_endAddress, Serial_RX_buffer_rp
	SK_EQ
	RETURN
	STR	_Serial_RX_buffer_startAddress, Serial_RX_buffer_rp
	RETURN



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



; reset RX and buffers
Serial_RX_purge:
	BCF	RCSTA, CREN	; disable rx
	BANK0_1
	BCF	PIE1, RCIE	; disable rx interrupts
	BANK1_0
	MOVLW	_Serial_RX_buffer_startAddress	;reset buffer pointers
	MOVWF	Serial_RX_buffer_wp
	MOVWF	Serial_RX_buffer_rp
	MOVF	RCREG, W	; 	purge receive register
	MOVF	RCREG, W
	BANK0_1
	BSF	PIE1, RCIE	; enable rx interrupts
	BANK1_0
	BSF	RCSTA, CREN	; enable rx
	RETURN



; block wait until data is available from ausart without using interrupts and buffers
Serial_RX_directRead:
	BSF	WaitRX_red
	BANK0_1
	BCF	PIE1, RCIE	; disable rx interrupts
	BANK1_0
Serial_RX_directRead_2:
	BSF	RCSTA, CREN
	BTFSS	RCSTA, OERR
	GOTO	Serial_RX_directRead_3
	BCF	RCSTA, CREN
	MOVF	RCREG, W
	MOVF	RCREG, W
	BSF	RCSTA, CREN
Serial_RX_directRead_3:
	BTFSC	RCSTA, FERR
	MOVF	RCREG, W
	
	BTFSS	PIR1, RCIF
	GOTO	Serial_RX_directRead_2
	MOVF	RCREG, W
	MOVWF	Serial_Data
	BCF	RCSTA, CREN

	BANK0_1
	BSF	PIE1, RCIE	; enable rx interrupts
	BANK1_0
	BCF	WaitRX_red
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
	
	MOVWF	bytetoConvert
	CALL	WriteHex
	MOVF	data_H10, W
	MOVWF	bytetoConvert
	CALL	WriteHex
	MOVF	data_H01, W
	MOVWF	bytetoConvert
	CALL	WriteHex
	
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

;	Set PC just after the next 256 byte boundary
	ORG	( $ & 0xFFFFFF00 ) + 0x100
	
WriteHex:
	MOVLW	high (NibbleHex)
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
	
NibbleHex:
	ADDWF	PCL, F
	dt	"0123456789ABCDEF"
	
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
