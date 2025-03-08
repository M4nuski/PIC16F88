	LIST		p=16F88		; processor model
	#INCLUDE	<P16F88.INC>	; processor specific variable definitions
	#INCLUDE	<PIC16F88_Macro.asm>

	__CONFIG	_CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & _WDT_OFF & _EXTCLK; _INTRC_IO;_EXTCLK
	__CONFIG	_CONFIG2, _IESO_OFF & _FCMEN_OFF

; Bank #    SFR           GPR               SHARED GPR's			total 368 bytes of GPR, 16 shared between banks
; Bank 0    0x00-0x1F     0x20-0x7F         target area 0x70-0x7F		96
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  			80 (+ top 16 shared with bank 0)
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F			16 + 80 (+ top 16 shared with bank 0)
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF			16 + 80 (+ top 16 shared with bank 0)

; Pinout:
; pin  1 PORTA2	
; pin  2 PORTA3	
; pin  3 PORTA4
; pin  4 PORTA5	(Input Only) MCLR
; pin  5 VSS		GND
; pin  6 PORTB0	
; pin  7 PORTB1	
; pin  8 PORTB2	Input	RX
; pin  9 PORTB3	
; pin 10 PORTB4
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


	ORG     0x0000

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
	
	BANK0
	
	BSF	RCSTA, SPEN	; serial port enabled
	BCF	RCSTA, RX9	; 8 bit rx
	;BSF	RCSTA, SREN	; not used in async - enable single receive
	BSF	RCSTA, CREN	; enable continuous receive
	BCF	RCSTA, ADDEN	; disable addressing
	



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
	
main:

	CALL WAIT_BYTE
	ADDLW	1
	CALL SEND_BYTE
	
	CALL WAIT_BYTE
	ADDLW	255
	CALL SEND_BYTE
	
	GOTO main


SEND_BYTE:
	BTFSS	PIR1, TXIF
	GOTO	SEND_BYTE
	MOVWF	TXREG
	RETURN
	
WAIT_BYTE:
	BTFSS	PIR1, RCIF
	GOTO	WAIT_BYTE
	MOVF	RCREG, W
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
