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


WaitForChar		EQU	0x25
TZ_offset		EQU	0x26
Temp			EQU	0x27

data_H10		EQU	0x28
data_H01		EQU	0x29
data_m10		EQU	0x2A
data_m01		EQU	0x2B
data_s10		EQU	0x2C
data_s01		EQU	0x2D

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


;SCRATCH		EQU	0x7A
; For ISR context
;STACK_SCRATCH	EQU	0x7B
;STACK_FSR	EQU	0x7C
;STACK_PCLATH	EQU	0x7D
;STACK_STATUS	EQU	0x7E
;STACK_W	EQU	0x7F

;#############################################################################
;	Reset Vector - Main Entry Point
;#############################################################################

	ORG     0x0000
	GOTO	SETUP

;#############################################################################
;	Interrupt Vector - Interrupt Service Routine
;#############################################################################

	ORG	0x0004
	PUSH
	PUSHfsr
	
	BTFSC	PIR1, RCIF	; 	check if RX interrupt
	GOTO	ISR_RX
	BTFSC	PIR1, TXIF	; 	check if TX interrupt
	GOTO	ISR_TX
	
	BSF	isr_RX_SQred
	BSF	isr_TX_SQgreen
	
	GOTO	ISR_END 	;	unkown interrupt
	
ISR_RX:

	BSF	isr_RX_SQred	
	
	BTFSC	RCSTA, FERR	;	check for framing error
	BSF	FrameError_yellow
	
ISR_RX1:
	MOVF	Serial_RX_buffer_wp, W	
	MOVWF	FSR		;	FSR = writePtr

	MOVF	RCREG, W	;	w = RXdata
	MOVWF	INDF		;	@writePtr = RXdata	
	
	INCF	Serial_RX_buffer_wp, F	;	writePtr++		
	MOVF	Serial_RX_buffer_wp, W	;	w = writePtr
	SUBLW	_Serial_RX_buffer_endAddress	;	w = _Serial_RX_buffer_endAddress - writePtr
	
	BTFSS	STATUS, Z	;	if (_Serial_RX_buffer_endAddress != writePtr)
	GOTO	ISR_RX2		;	check if another byte is ready
	
	MOVLW	_Serial_RX_buffer_startAddress;	else
	MOVWF	Serial_RX_buffer_wp	;	writePtr = _Serial_RX_buffer_startAddress

ISR_RX2:
	BTFSC	PIR1, RCIF	;	loop back if interrupt flag is still set
	GOTO	ISR_RX1
	
	BTFSS	RCSTA, OERR	; 	check for buffer overrun error
	GOTO	ISR_RX_END
	BSF	OverrunError_yellow
	BCF	RCSTA, CREN	; 	reset rx
	MOVF	RCREG, W	; 	purge receive register
	MOVF	RCREG, W
	BSF	RCSTA, CREN	
	
ISR_RX_END
	BTFSS	PIR1, TXIF	; 	check if also TX interrupt
	GOTO	ISR_END	
	
ISR_TX:
	BSF	isr_TX_SQgreen
	; if buffer start != buffer end
	; send byte
	; else 
	; disable TX interrupt
	; 	BCF	TX_green
	MOVF	Serial_TX_buffer_rp, W
	SUBWF	Serial_TX_buffer_wp, W
	BR_EQ	ISR_TX_empty
	
	MOVF	Serial_TX_buffer_rp, W
	MOVWF	FSR
	MOVF	INDF, W
	MOVWF	TXREG
	
	INCF	Serial_TX_buffer_rp, F
	MOVF	Serial_TX_buffer_rp, W
	SUBLW	_Serial_TX_buffer_endAddress
	BTFSS	STATUS, Z
	GOTO	ISR_END
	MOVLW	_Serial_TX_buffer_startAddress
	MOVWF	Serial_TX_buffer_rp
	GOTO	ISR_END
	
ISR_TX_empty:
	BCF	TX_green
	BANK1
	BCF	PIE1, TXIE	; disable tx interrupts	
	BANK0
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
	
	BANKSEL	PIE1
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
	
	STR 	'U', Serial_Data	
	CALL 	BLOCK_SEND_BYTE	
	STR	'A', Serial_Data	
	CALL 	BLOCK_SEND_BYTE
	STR	'R', Serial_Data	
	CALL 	BLOCK_SEND_BYTE	
	STR	'T', Serial_Data	
	CALL 	BLOCK_SEND_BYTE	
	
	STR	' ', Serial_Data	
	CALL 	BLOCK_SEND_BYTE
	
	STR	'5', Serial_Data	
	CALL 	BLOCK_SEND_BYTE	
	
	STR	13, Serial_Data		;(CR)
	CALL 	BLOCK_SEND_BYTE	
	STR	10, Serial_Data		;(LF)
	CALL 	BLOCK_SEND_BYTE
	
	CLRF	PORTA
	CLRF	PORTB
	
; enable interrupts
	BSF	INTCON, PEIE ; peripheral int
	BSF	INTCON, GIE  ; global int


;#############################################################################
;	Main Loop	
;#############################################################################


	
LOOP:
	CALL	WAIT_25ms
	BCF	OverrunError_yellow
	BCF	FrameError_yellow

;read:
;	CALL	AVAIL_BYTE
;	CMP_lW	TRUE
;	BR_NE	LOOP	
;	CALL	READ_BYTE
;	CMP_lf	32, Serial_Data
;	BR_GE	nomod		; if 32 >= data skip the mod
;	INCF	Serial_Data, F	; modify data
;nomod:
;	CALL	SEND_BYTE	; send the byte from Serial_Data
	
;	GOTO	read

	CALL	READ_NEXT_TIME
	BW_False	NO_TIME
	
	MOV	data_H10, Serial_Data
	CALL	SEND_BYTE
	MOV	data_H01, Serial_Data
	CALL	SEND_BYTE
	
	STR	':', Serial_Data
	CALL 	SEND_BYTE
	
	MOV	data_m10, Serial_Data
	CALL	SEND_BYTE
	MOV	data_m01, Serial_Data
	CALL	SEND_BYTE
	
	STR	':', Serial_Data
	CALL 	SEND_BYTE
	
	MOV	data_s10, Serial_Data
	CALL	SEND_BYTE
	MOV	data_s01, Serial_Data
	CALL	SEND_BYTE
	
	STR	'Z', Serial_Data
	CALL 	SEND_BYTE
	STR	' ', Serial_Data
	CALL 	SEND_BYTE
	
	
	MOVLW	5
	BTFSC	TZ_Select
	MOVLW	4
	MOVWF	TZ_offset
	
	CALL	ADJUST_TZ
	
	GOTO	LOOP
	
NO_TIME:
	STR	'N', Serial_Data
	CALL 	SEND_BYTE
	STR	'o', Serial_Data
	CALL 	SEND_BYTE
	STR	' ', Serial_Data
	CALL 	SEND_BYTE
	STR	'T', Serial_Data
	CALL 	SEND_BYTE
	STR	'i', Serial_Data
	CALL 	SEND_BYTE
	STR	'm', Serial_Data
	CALL 	SEND_BYTE
	STR	'e', Serial_Data
	CALL 	SEND_BYTE
	STR	' ', Serial_Data
	CALL 	SEND_BYTE
	STR	'D', Serial_Data
	CALL 	SEND_BYTE
	STR	'a', Serial_Data
	CALL 	SEND_BYTE
	STR	't', Serial_Data
	CALL 	SEND_BYTE
	STR	'a', Serial_Data
	CALL 	SEND_BYTE
	
	CALL	WriteEOL
	
	GOTO	LOOP
	
;#############################################################################
;	Subroutines
;#############################################################################
	
SEND_BYTE:
	BANK1
	BCF	PIE1, TXIE	; disable tx interrupts	
	BANK0
	BSF	TX_green
	
	MOVF	Serial_TX_buffer_wp, W	; add data to TX buffer
	MOVWF	FSR
	MOVF	Serial_Data, W
	MOVWF	INDF
	
	INCF	Serial_TX_buffer_wp, F	; advance pointer
	MOVF	Serial_TX_buffer_wp, W
	SUBLW	_Serial_TX_buffer_endAddress
	BTFSS	STATUS, Z
	GOTO	SEND_BYTE_END
	MOVLW	_Serial_TX_buffer_startAddress
	MOVWF	Serial_TX_buffer_wp	
SEND_BYTE_END:
	BANK1
	BSF	PIE1, TXIE	; enable tx interrupts	
	BANK0
	RETURN
	
BLOCK_SEND_BYTE:
	BSF	TX_green
	BTFSS	PIR1, TXIF
	GOTO	BLOCK_SEND_BYTE
	MOVF	Serial_Data, W
	MOVWF	TXREG
	BCF	TX_green
	RETURN

AVAIL_BYTE:	; check if a RX byte is available, return with 0 in W if avail, 1 in W if not
	MOVF	Serial_RX_buffer_wp, W
	SUBWF	Serial_RX_buffer_rp, W
	SK_EQ
	RETLW	TRUE	; pointers are not equal
	RETLW	FALSE	; both pointers are equal

WAIT_BYTE:
	BSF	WaitRX_red
	MOVF	Serial_RX_buffer_wp, W
	SUBWF	Serial_RX_buffer_rp, W
	BTFSC	STATUS, Z
	GOTO	WAIT_BYTE	
	BCF	WaitRX_red
	RETURN
	
; TODO TX_AVAIL
; TODO TX_WAIT_AVAIL

READ_BYTE:
	; read current rx buffer, advance pointer, return with data in Serial_Data
	MOVF	Serial_RX_buffer_rp, W
	MOVWF	FSR
	INCF	Serial_RX_buffer_rp, F
	MOVF	Serial_RX_buffer_rp, W
	SUBLW	_Serial_RX_buffer_endAddress
	BTFSS	STATUS, Z
	GOTO	READ_BYTE_END
	MOVLW	_Serial_RX_buffer_startAddress
	MOVWF	Serial_RX_buffer_rp
READ_BYTE_END:
	MOVF	INDF, W
	MOVWF	Serial_Data
	RETURN


BLOCK_READ_BYTE:
	BSF	WaitRX_red
	;busy wait
	CMP_ff	Serial_RX_buffer_wp, Serial_RX_buffer_rp
	BR_EQ	BLOCK_READ_BYTE
	;set address
	MOV	Serial_RX_buffer_rp, FSR
	;inc address
	INCF	Serial_RX_buffer_rp, F	
	CMP_lf	_Serial_RX_buffer_endAddress, Serial_RX_buffer_rp
	BR_NE	BLOCK_READ_BYTE_END
	STR	_Serial_RX_buffer_startAddress, Serial_RX_buffer_rp
	;read
BLOCK_READ_BYTE_END:
	MOV	INDF, Serial_Data
	BCF	WaitRX_red
	RETURN




; $GPGGA,205654.00,
READ_NEXT_TIME:
	CALL	BLOCK_READ_BYTE
	CMP_lf	'$', Serial_Data
	BR_NE	READ_NEXT_TIME
	
	CALL	BLOCK_READ_BYTE
	CMP_lf	'G', Serial_Data
	BR_NE	READ_NEXT_TIME

	CALL	BLOCK_READ_BYTE
	CMP_lf	'P', Serial_Data
	BR_NE	READ_NEXT_TIME
	
	CALL	BLOCK_READ_BYTE
	CMP_lf	'G', Serial_Data
	BR_NE	READ_NEXT_TIME
	
	CALL	BLOCK_READ_BYTE
	CMP_lf	'G', Serial_Data
	BR_NE	READ_NEXT_TIME
	
	CALL	BLOCK_READ_BYTE
	CMP_lf	'A', Serial_Data
	BR_NE	READ_NEXT_TIME
	
	CALL	BLOCK_READ_BYTE
	CMP_lf	',', Serial_Data
	BR_NE	READ_NEXT_TIME
	
	
	CALL	BLOCK_READ_BYTE
	CMP_lf	',', Serial_Data
	SK_NE
	RETLW	FALSE
	MOV	Serial_Data, data_H10
	
	CALL	BLOCK_READ_BYTE
	MOV	Serial_Data, data_H01
	
	CALL	BLOCK_READ_BYTE
	MOV	Serial_Data, data_m10
	
	CALL	BLOCK_READ_BYTE
	MOV	Serial_Data, data_m01
	
	CALL	BLOCK_READ_BYTE
	MOV	Serial_Data, data_s10
	
	CALL	BLOCK_READ_BYTE
	MOV	Serial_Data, data_s01
	
	RETLW	TRUE
	
ADJUST_TZ:
	; adjust timezone
	SUBL	data_H01, '0'; ascii to int
	SUBL	data_H10, '0'; ascii to int
	
	;CLRF	STATUS
	;RLF	data_H10, F ; h10  = 2*h10
	;MOVF	data_H10, W ; w = 2*h10
	;CLRF	STATUS
	;RLF	data_H10, F ; h10  = 4*h10
	;RLF	data_H10, F ; h10  = 8*h10
	;ADDWF	data_H10, W
	MOVF	data_H10, W ; w = 1*h10
	ADDWF	data_H10, W ; w = 2*h10
	ADDWF	data_H10, W ; w = 3*h10
	ADDWF	data_H10, W ; w = 4*h10
	ADDWF	data_H10, W ; w = 5*h10
	
	ADDWF	data_H10, W ; w = 6*h10
	ADDWF	data_H10, W ; w = 7*h10
	ADDWF	data_H10, W ; w = 8*h10
	ADDWF	data_H10, W ; w = 9*h10
	ADDWF	data_H10, W ; w = 10*h10
	
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
	
	MOV	data_H10, Serial_Data
	CALL	SEND_BYTE
	MOV	data_H01, Serial_Data
	CALL	SEND_BYTE
	
	STR	':', Serial_Data
	CALL 	SEND_BYTE
	
	MOV	data_m10, Serial_Data
	CALL	SEND_BYTE
	MOV	data_m01, Serial_Data
	CALL	SEND_BYTE
	
	STR	':', Serial_Data
	CALL 	SEND_BYTE
	
	MOV	data_s10, Serial_Data
	CALL	SEND_BYTE
	MOV	data_s01, Serial_Data
	CALL	SEND_BYTE
	
	STR	'E', Serial_Data
	CALL 	SEND_BYTE
	
	MOVLW	'S'
	BTFSC	TZ_select
	MOVLW	'D'
	MOVWF	Serial_Data
	CALL 	SEND_BYTE
	
	STR	'T', Serial_Data
	CALL 	SEND_BYTE
	
	CALL	WriteEOL

	RETURN





;	Set PC just after the next 256 byte boundary
	ORG	( $ & 0xFFFFFF00 ) + 0x100
NibbleHex:
	ADDWF	PCL, F
	RETLW	'0'
	RETLW	'1'
	RETLW	'2'
	RETLW	'3'
	
	RETLW	'4'
	RETLW	'5'
	RETLW	'6'
	RETLW	'7'
	
	RETLW	'8'
	RETLW	'9'
	RETLW	'A'
	RETLW	'B'
	
	RETLW	'C'
	RETLW	'D'
	RETLW	'E'
	RETLW	'F'
	
WriteHex:
	MOVLW	high (NibbleHex)
	MOVWF	PCLATH
	SWAPF	WaitForChar, W
	ANDLW	0x0F
	CALL	NibbleHex
	MOVWF	Serial_Data
	CALL 	SEND_BYTE
	MOVF	WaitForChar, W
	ANDLW	0x0F
	CALL	NibbleHex
	MOVWF	Serial_Data
	CALL 	SEND_BYTE
	RETURN
	
WriteSpace:
	MOVLW	' '
	MOVWF	Serial_Data
	CALL 	SEND_BYTE	
	RETURN
WriteEOL:
	MOVLW	13		;(CR)
	MOVWF	Serial_Data
	CALL 	SEND_BYTE	
	MOVLW	10		;(LF)
	MOVWF	Serial_Data
	CALL 	SEND_BYTE
	RETURN

;Serial_RX_read		busy wait for next available data and read next byte in rx buffer
;Serial_RX_isQueueFull
;Serial_RX_isByteAvailable
;Serial_RX_wait		busy wait for byte in rx buffer
;Serial_RX_forceRead		read next byte in buffer immediatly
;Serial_RX_directRead		busy wait to read reg directly, no interrupts
;Serial_RX_purge

;Serial_TX_write		busy wait to write to tx buffer when available
;Serial_TX_isQueueFull
;Serial_TX_isByteAvailable
;Serial_TX_wait		busy wait for avaiable byte in tx buffer
;Serial_TX_forceWrite		add byte to tx buffer even if full
;Serial_TX_directWrite	busy wait to write reg directly, no interrupts
;Serial_TX_purge

;Serial_hasError

; Serial_Status
;_Serial_bit_RX_avail 
;_Serial_bit_TX_avail 
;_Serial_bit_RX_frameError 
;_Serial_bit_RX_overrunERror 
;_Serial_bit_TX_bufferOverrun
;_Serial_bit_RX_bufferOverrun 
;_Serial_bit_RX_bufferFull
;_Serial_bit_TX_bufferFull

; Serial_Data	Byte buffer to get and set data to serial methods
; Serial_TX_buffer_wp
; Serial_TX_buffer_rp
; Serial_RX_buffer_wp
; Serial_RX_buffer_rp
;  _Serial_TX_buffer_startAddress
;  _Serial_RX_buffer_startAddress
;  _Serial_TX_buffer_endAddress
;  _Serial_RX_buffer_endAddeess

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
	RETURN				; return 2 cycles



;#############################################################################
;	End Declaration
;#############################################################################

	END
