;#############################################################################
;	UART Test 4
;	Loopback
;	Circular RX buffer
;	Circular TX buffer
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
; pin  3 IOA PORTA4
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
; pin 15 _O_ PORTA6	
; pin 16 I__ PORTA7	
; pin 17 IOA PORTA0	
; pin 18 IOA PORTA1

#DEFINE isr_TX_SQgreen	PORTA, 2
#DEFINE isr_RX_SQred		PORTA, 3
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

count_01ms	EQU	0x20
count_25ms	EQU	0x21
count_1s	EQU	0x22

;Result		EQU 	0x23 ; 0x24
;BCD		EQU	0x25 ; 0x26 0x27 0x28
;count_BCD1	EQU	0x29
;count_BCD2	EQU	0x2A

RXTX_Data	EQU	0x2B

RXBufStart	EQU	0x30 ; circular RX buffer start
RXBufEnd	EQU	0x50 ; circular RX buffer end

TXBufStart	EQU	0x50 ; circular TX buffer start
TXBufEnd	EQU	0x70 ; circular TX buffer end

;#############################################################################
;	Shared Files 0x70 - 0x7F
;#############################################################################

RXBuf_rp	EQU	0x70 ; circular RX buffer read pointer
RXBuf_wp	EQU	0x71 ; circular RX buffer write pointer

TXBuf_rp	EQU	0x72 ; circular TX buffer read pointer
TXBuf_wp	EQU	0x73 ; circular TX buffer write pointer

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
	MOVF	RXBuf_wp, W	
	MOVWF	FSR		;	FSR = writePtr

	MOVF	RCREG, W	;	w = RXdata
	MOVWF	INDF		;	@writePtr = RXdata	
	
	INCF	RXBuf_wp, F	;	writePtr++		
	MOVF	RXBuf_wp, W	;	w = writePtr
	SUBLW	RXBufEnd	;	w = RXBufEnd - writePtr
	
	BTFSS	STATUS, Z	;	if (RXBufEnd != writePtr)
	GOTO	ISR_RX2		;	check if another byte is ready
	
	MOVLW	RXBufStart	;	else
	MOVWF	RXBuf_wp	;	writePtr = RXBufStart

ISR_RX2:
	BTFSC	PIR1, RCIF	;	loop back if interrupt flag is still set
	GOTO	ISR_RX1
	
	BTFSS	RCSTA, OERR	; 	check for buffer overrun error
	GOTO	ISR_END
	BSF	OverrunError_yellow
	BCF	RCSTA, CREN	; 	reset rx
	MOVF	RCREG, W	; 	purge receive register
	MOVF	RCREG, W
	BSF	RCSTA, CREN	
	GOTO	ISR_END
	
ISR_TX:
	BSF	isr_TX_SQgreen
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	GOTO	ISR_END

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
	BCF	RCSTA, ADDEN	; disable addressing 12345678
	

; initialize circular buffer pointers
	MOVLW	RXBufStart
	MOVWF	RXBuf_rp
	MOVWF	RXBuf_wp
	
;welcome message
	CALL	WAIT_1s
	
	STR 	'U', RXTX_Data	
	CALL 	SEND_BYTE	
	STR	'A', RXTX_Data	
	CALL 	SEND_BYTE	
	STR	'R', RXTX_Data	
	CALL 	SEND_BYTE	
	STR	'T', RXTX_Data	
	CALL 	SEND_BYTE	
	
	STR	' ', RXTX_Data	
	CALL 	SEND_BYTE	
	STR	'4', RXTX_Data	
	CALL 	SEND_BYTE	
	
	STR	13, RXTX_Data		;(CR)
	CALL 	SEND_BYTE	
	STR	10, RXTX_Data		;(LF)
	CALL 	SEND_BYTE
	
	CLRF	PORTA
	CLRF	PORTB
	
; enable interrupts
	BSF	INTCON, PEIE ; peripheral int
	BSF	INTCON, GIE  ; global int



;#############################################################################
;	Main Loop	
;#############################################################################

LOOP:

	CALL	WAIT_BYTE	; wait until rx buffer.length > 0
	CALL	READ_BYTE	; read a byte to RXTX_Data	
	CALL	SEND_BYTE	; send the byte from RXTX_Data
	
	COMP_l_f	32, RXTX_Data
	BR_GE	nomod		; if 32 >= data skip the mod
	INCF	RXTX_Data, F	; modify data
	CALL	SEND_BYTE	; send the byte from RXTX_Data
nomod:
	BCF	OverrunError_yellow
	BCF	FrameError_yellow

	GOTO	LOOP
	
;#############################################################################
;	Subroutines
;#############################################################################
	


SEND_BYTE:
	BSF	TX_green
	BTFSS	PIR1, TXIF
	GOTO	SEND_BYTE
	MOVF	RXTX_Data, W
	MOVWF	TXREG
	BCF	TX_green
	RETURN

AVAIL_BYTE:	; check if a RX byte is available, return with 1 in W if avail, 0 in W if not
	MOVF	RXBuf_wp, W
	SUBWF	RXBuf_rp, W
	BTFSC	STATUS, Z
	RETLW	0x00
	RETLW	0x01

WAIT_BYTE:
	BSF	WaitRX_red
	MOVF	RXBuf_wp, W
	SUBWF	RXBuf_rp, W
	BTFSC	STATUS, Z
	GOTO	WAIT_BYTE
	BCF	WaitRX_red
	RETURN

READ_BYTE:
	; read current rx buffer, advance pointer, return with data in RXTX_Data
	MOVF	RXBuf_rp, W
	MOVWF	FSR
	INCF	RXBuf_rp, F
	MOVF	RXBuf_rp, W
	SUBLW	RXBufEnd
	BTFSS	STATUS, Z
	GOTO	READ_BYTE_R
	MOVLW	RXBufStart
	MOVWF	RXBuf_rp
READ_BYTE_R:
	MOVF	INDF, W
	MOVWF	RXTX_Data
	RETURN



;#############################################################################
;	Delay routines	
;#############################################################################

WAIT_1s:
	MOVLW	40
	MOVWF	count_1s
WAIT_1s_loop:
	NOP
	CALL	WAIT_25ms
	DECFSZ	count_1s, F
	GOTO	WAIT_1s_loop
	RETURN

WAIT_25ms:				; call 2 cycles
	MOVLW	250			; for 25 ms
	MOVWF	count_25ms		
WAIT_25ms_loop:
	NOP
	CALL	WAIT_01ms
	DECFSZ	count_25ms, F
	GOTO	WAIT_25ms_loop
	RETURN

; at 8MHz, each instruction is 0.5 us
WAIT_01ms:				; call 2 cycle
	MOVLW	50 - 2			; (1) 50 loops of 4 cycles (minus 2 loops for call, setup and return) 
	MOVWF	count_01ms		; (1) 
	NOP				; (1) 
	NOP				; (1) 
					; setup is 4 cycles
WAIT_01ms_loop:			; 4 cycles per loop
	NOP				; (1) 
	DECFSZ	count_01ms, F		; (1) 
	GOTO	WAIT_01ms_loop		; (2) 
	RETURN				; return 2 cycles

;#############################################################################
;	End Declaration
;#############################################################################

	END
