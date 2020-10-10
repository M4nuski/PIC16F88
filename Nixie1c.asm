	LIST		p=16F88		; processor model
	#INCLUDE	<P16F88.INC>	; processor specific variable definitions
	#INCLUDE	<PIC16F88_Macro.asm>

	__CONFIG	_CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & _WDT_OFF & _INTRC_IO
	__CONFIG	_CONFIG2, _IESO_OFF & _FCMEN_OFF

; Bank #    SFR           GPR               SHARED GPR's			total 368 bytes of GPR, 16 shared between banks
; Bank 0    0x00-0x1F     0x20-0x7F         target area 0x70-0x7F		96 0x70 to 0x7F are shared
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  			80 + top 16 shared with bank 0
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F			80 + top 16 shared with bank 0
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF			80 + top 16 shared with bank 0

; Pinout:
; pin  1 PORTA2	
; pin  2 PORTA3	
; pin  3 PORTA4
; pin  4 PORTA5	(Input Only) MCLR
; pin  5 VSS		GND
; pin  6 PORTB0	WaitRX_red
#DEFINE	WaitRX_red PORTB, 0
; pin  7 PORTB1	OverrunError_yellow
#DEFINE	OverrunError_yellow PORTB, 1
; pin  8 PORTB2	Input	RX
; pin  9 PORTB3	TX_green
#DEFINE	TX_green PORTB, 3

; pin 10 PORTB4
#DEFINE	FrameError_yellow PORTB, 4
; pin 11 PORTB5	Output TX
; pin 12 PORTB6
; pin 13 PORTB7
; pin 14 VDD		VCC
; pin 15 PORTA6	(Output only)
; pin 16 PORTA7	(Input only) send data switch
; pin 17 PORTA0	
; pin 18 PORTA1


;Variables declarations:
	
count_01ms	EQU	0x20
count_25ms	EQU	0x21
count_1s	EQU	0x22
Result		EQU 	0x23 ; 0x24
BCD		EQU	0x25 ; 0x26 0x27 0x28
count_BCD1	EQU	0x29
count_BCD2	EQU	0x2A

serialBuffer	EQU	0x30 ; up to 0x50

; Const
serialBufMax	EQU	32

; Shared mem
serialBufLen	EQU	0x7C 

; For ISR context
STACK_PCLATH	EQU	0x7D
STACK_STATUS	EQU	0x7E
STACK_W		EQU	0x7F




	; Entry point	
	ORG     0x0000
	GOTO	SETUP


	
	; ISR
	ORG	0x0004
	qPUSH
	
ISR_RX:
	BTFSS	PIR1, RCIF	; check if RX interrupt
	GOTO	ISR_END
	
	
	MOVF	serialBuffer, W;	w = *buffer[0]
	ADDWF	serialBufLen, W;	w = *buffer[0] + len 
	MOVWF	FSR		;	FSR = *buffer[len] (INDF = buffer[len])
	
	MOVF	RCREG, W	;	w = RXdata
	MOVWF	INDF		;	buffer[len] = RXdata	
	
	INCF	serialBufLen, F;	len++
		
	MOVF	serialBufLen, W;	w = len
	SUBLW	serialBufMax	;	w = max - len
	BTFSC	STATUS, Z	;	if (len == max) len = 0
	CLRF	serialBufLen


	GOTO	ISR_RX		; check if another byte is ready
	
ISR_END:
	qPOP
	RETFIE
	
	

SETUP:

	BANK1
	
	; init port directions 
	CLRF	TRISA		; all outputs
	
	CLRF	TRISB		; all outputs
	BSF	TRISB, 2	; input RX
	
	; init analog inputs
	CLRF	ANSEL		; all digital
	
	; init osc 8MHz
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
	;BSF	TXSTA, CSRC	; not used in async - set as clock source master
	BCF 	TXSTA, TX9	; 8 bit tx
	BSF	TXSTA, TXEN	; enable tx
	BCF	TXSTA, SYNC	; async
	
	; set 9600 baud rate
	BSF 	TXSTA, BRGH	; high speed baud rate generator	
	MOVLW	51		; 9600 bauds
	MOVWF	SPBRG
	
	BSF	PIE1, RCIE	; enable rx int
	
	BANK0
	
	BSF	RCSTA, SPEN	; serial port enabled
	BCF	RCSTA, RX9	; 8 bit rx
	;BSF	RCSTA, SREN	; not used in async - enable single receive
	BSF	RCSTA, CREN	; enable continuous receive
	BCF	RCSTA, ADDEN	; disable addressing
	
	;BSF	T1CON, T1CKPS1 ; div4 pre sdcaler
	


;welcome message
	CALL	WAIT_1s	
	
	MOVLW	'P'
	CALL 	SEND_BYTE	
	MOVLW	'I'
	CALL 	SEND_BYTE
	MOVLW	'C'
	CALL 	SEND_BYTE
	
	MOVLW	'1'
	CALL 	SEND_BYTE	
	MOVLW	'6'
	CALL 	SEND_BYTE
	
	MOVLW	'F'
	CALL 	SEND_BYTE
	
	MOVLW	'8'
	CALL 	SEND_BYTE
	MOVLW	'8'
	CALL 	SEND_BYTE	
	
	MOVLW	13	;(CR)
	CALL 	SEND_BYTE	
	MOVLW	10	;(LF)
	CALL 	SEND_BYTE
	
	BSF	INTCON, PEIE ; peripheral int
	BSF	INTCON, GIE  ; global int
	
	; Main Loop
	
	
LOOP:

	BCF	T1CON, TMR1ON
	CLRF	TMR1L
	CLRF	TMR1H
	
	CALL	WAIT_BYTE
	;MOVWF Result
	;MOVLW '0'
	;SUBWF Result, W
	;BTFSS STATUS, Z
	;GOTO main
	
	; start timer1
	
;	BSF	T1CON, TMR1ON
	
	CALL	WAIT_BYTE
	;MOVWF Result
	;MOVLW '1'
	;SUBWF Result, W
	;BTFSS STATUS, Z	
	;GOTO main
	
	; stop timer1
;	BCF	T1CON, TMR1ON
	
	;MOVF	TMR1L, W
	;MOVWF	Result
	;MOVF	TMR1H, W
	;MOVWF	Result + 1
	

	CALL	BIN2BCD
	BSF	T1CON, TMR1ON
	
	MOVLW	13	;(CR)
	CALL 	SEND_BYTE	
	MOVLW	10	;(LF)
	CALL 	SEND_BYTE
	
	CALL	SEND_BCD
	BCF	T1CON, TMR1ON
	MOVF	TMR1L, W
	MOVWF	Result
	MOVF	TMR1H, W
	MOVWF	Result + 1
	
	BCF	OverrunError_yellow
	BCF	FrameError_yellow
	; send data
	; low byte
	;MOVLW 0xE4
	;;MOVF TMR1L, W
	;;CALL SEND_BYTE
	
	; high byte
	;MOVLW 0x07
	;;SWAPF	TMR1H, W
	;;ANDLW	0x0F
	;;ADDLW	'A'
	;;CALL SEND_BYTE
	
	
	GOTO	LOOP

SEND_BCD:
	SWAPF	BCD + 1, W	; high nibble
	ANDLW	0x0F
	ADDLW	0x30		; ascii 0 = 0x30
	CALL 	SEND_BYTE
	
	MOVF	BCD + 1, W	 ; low nibble
	ANDLW	0x0F
	ADDLW	0x30
	CALL 	SEND_BYTE
	
	SWAPF	BCD, W		; high nibble
	ANDLW	0x0F
	ADDLW	0x30
	CALL 	SEND_BYTE
	
	MOVF	BCD, W		; low nibble
	ANDLW	0x0F
	ADDLW	0x30
	CALL 	SEND_BYTE
	
	RETURN
	
SEND_BYTE:
	BSF	TX_green
	BTFSS	PIR1, TXIF
	GOTO	SEND_BYTE
	MOVWF	TXREG
	BCF	TX_green
	RETURN

CHECK_AVAIL
CHECK_ERROR
CLEAR_ERROR
CLEAR_BUFFER

WAIT_BYTE
	MOVF	serialBufLen, F
	BTFSC	STATUS, Z

;WAIT_BYTE:	
;	BSF	WaitRX_red
	;BSF	RCSTA, CREN
	;BTFSS	RCSTA, OERR
;	GOTO	WAIT_BYTE2
;	BSF	OverrunError_yellow
;	BCF	RCSTA, CREN
;	MOVF	RCREG, W
;	MOVF	RCREG, W
;	BSF	RCSTA, CREN
;WAIT_BYTE2:
;	BTFSS	RCSTA, FERR
;	GOTO	WAIT_BYTE3
;	BSF	FrameError_yellow
;	MOVF	RCREG, W
	
;WAIT_BYTE3:
;	BTFSS	PIR1, RCIF
;	GOTO	WAIT_BYTE
;	MOVF	RCREG, W
;	BCF	RCSTA, CREN
;	BCF	WaitRX_red
;	RETURN

;Result to Packed BCD, 16 bit input, max value is 65536, 2.5 BCD bytes (x6 55 36)
BIN2BCD:
	CLRF	BCD
	CLRF	BCD + 1
	CLRF	BCD + 2
	MOVLW	15		; Rotate and Increment 15 time
	MOVWF	count_BCD1

BIN2BCD_mainLoop:
 	BCF	STATUS, C
	RLF	Result, F
	RLF	Result + 1, F
	RLF	BCD, F
	RLF	BCD + 1, F
	RLF	BCD + 2, F

	MOVLW	BCD
	MOVWF	FSR

	MOVLW	0x03
	MOVWF	count_BCD2
	
BIN2BCD_highNibble:
	SWAPF	INDF, W	
	ANDLW	0x0F
	SUBLW	0x04
	BTFSC	STATUS, C
	GOTO	BIN2BCD_lowNibble
	MOVLW	0x30
	ADDWF	INDF, F

BIN2BCD_lowNibble:
	MOVLW	0x0F
	ANDWF	INDF, W
	SUBLW	0x04
	BTFSC	STATUS, C
	GOTO	BIN2BCD_nextNibble
	MOVLW	0x03
	ADDWF	INDF, F		

BIN2BCD_nextNibble:
	INCF	FSR, F
	DECFSZ	count_BCD2, F
	GOTO	BIN2BCD_highNibble

	DECFSZ	count_BCD1, F
	GOTO	BIN2BCD_mainLoop

 	BCF	STATUS, C	; 16th Time no C5A3
	RLF	Result, F
	RLF	Result + 1, F
	RLF	BCD, F
	RLF	BCD + 1, F
	RLF	BCD + 2, F

	RETURN


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

WAIT_01ms:				; call 2 cycle
	MOVLW	50 - 2			; 50 loops of 4 cycles (minus setup and return) 
	MOVWF	count_01ms		; 1
	NOP				; 1 
	NOP				; 1
	; call and return 8 cycles
WAIT_01ms_loop:			;	4 per loop
	NOP				; 1
	DECFSZ	count_01ms, F		; 1
	GOTO	WAIT_01ms_loop		; 2
	RETURN				; return 2 cycles


	END
