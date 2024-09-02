;#############################################################################
;
;	Timer0 timing test for pooling
;
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
; pin  1 IOA PORTA2	
; pin  2 IOA PORTA3	
; pin  3 IOA PORTA4	
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O XOR on TMR0 pooling state change
; pin  7 IO_ PORTB1	
; pin  8 IOR PORTB2	RX
; pin  9 IO_ PORTB3	

; pin 10 IO_ PORTB4	
; pin 11 IOT PORTB5	O UART TX
; pin 12 IOA PORTB6	I ICSP PGC
; pin 13 IOA PORTB7	I ICSP PGD
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O ISR Status Bit
; pin 16 I_X PORTA7	
; pin 17 IOA PORTA0	
; pin 18 IOA PORTA1	


;#DEFINE 		PORTA, 0
;#DEFINE 		PORTA, 1
;#DEFINE 		PORTA, 2
;#DEFINE 		PORTA, 3
;#DEFINE 		PORTA, 4
;#DEFINE MCLR			PORTA, 5
#DEFINE pin_ISR		PORTA, 6
;#DEFINE 			PORTA, 7

#DEFINE pin_TMR0		PORTB, 0
#DEFINE mask_TMR0		0x01
#DEFINE pin_TMR0_INT		PORTB, 1
#DEFINE mask_TMR0_INT		0x02
;#DEFINE 		PORTB, 2
;#DEFINE 		PORTB, 3
;#DEFINE 		PORTB, 4
#DEFINE UART_TX		PORTB, 5
;#DEFINE 	PGC		PORTB, 6
;#DEFINE 	PGD		PORTB, 7

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


;#############################################################################
;	Reset Vector - Main Entry Point
;#############################################################################

	ORG	0x0000
	GOTO	SETUP

;#############################################################################
;	Interrupt Vector - Interrupt Service Routine
;#############################################################################

	ORG	0x0004
	PUSH		;W, STATUS, PCLATH
	PUSHfsr		;FSR
	;PUSHscr		;SCRATCH for extended bitlengths macro
	BSF	pin_ISR

	; select int
	BTFBS	PIR1, TMR1IF, ISR_T1
	BTFBS	INTCON, TMR0IF, ISR_T0
	
	GOTO	ISR_END 		; unkown interrupt
	
ISR_T0:
	BCF	INTCON, TMR0IF; clear flag
	MOVLW	mask_TMR0_INT
	XORWF	PORTB, F
	GOTO	ISR_END

ISR_T1:
	STR	b'11000000', TMR1H ;61.025Hz	
	BCF	PIR1, TMR1IF
	GOTO	ISR_END
	
ISR_END:
	BCF	pin_ISR
	;POPscr
	POPfsr
	POP
	RETFIE

;#############################################################################
;	Setup
;#############################################################################

SETUP:

	BANK1
	
	; init analog inputs
	CLRF	ANSEL		; all digital

	; init port directions
	CLRF	TRISA		; all outputs
	CLRF	TRISB		; all outputs
	
	; init osc 8MHz
	BCF	OSCCON, SCS0
	BCF	OSCCON, SCS1
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
SETUP_OSC:
	BTFSS	OSCCON, IOFS
	GOTO	SETUP_OSC
	
	; UART TX at 9600, 8 bit, async
	;BSF	TXSTA, CSRC	; not used in async - set as clock source master
	BCF 	TXSTA, TX9	; 8 bit tx
	BSF	TXSTA, TXEN	; enable tx
	BCF	TXSTA, SYNC	; async
	
	; set 9600 baud rate
	BSF 	TXSTA, BRGH	; high speed baud rate generator	
	MOVLW	51		; 9600 bauds @ 8MHz
	MOVWF	SPBRG
	

	; timer 0
	BCF	OPTION_REG, T0CS ; on instruction clock
	BCF	OPTION_REG, PSA ; pre scaler assigned to tmr0
	BCF	OPTION_REG, PS2 ; 0
	BSF	OPTION_REG, PS1 ; 1
	BCF	OPTION_REG, PS0 ; 0 for 1:8 tmr0 ps
	; tmr0 overlfow every 8*256 instructions, or 2048 instructions / 1.024ms
	
	
	;BSF	PIE1, TMR1IE	; enable TMR1 interrupt

	BANK0
	
	; ports setrup
	CLRF	PORTA
	CLRF	PORTB	

	; timer1
	CLRF	TMR1L
	CLRF	TMR1H
	BCF	T1CON, T1CKPS0	; no PS
	BCF	T1CON, T1CKPS1	;
	BCF	T1CON, TMR1CS	; timer1 clock is FOSC/4
	BSF	T1CON, TMR1ON	; timer1 ON
	
	; UART
	BSF	RCSTA, SPEN	; serial port enabled
	; UART RX
	;BCF	RCSTA, RX9	; 8 bit rx
	;BSF	RCSTA, SREN	; not used in async - enable single receive
	;BSF	RCSTA, CREN	; enable continuous receive
	;BCF	RCSTA, ADDEN	; disable addressing
	
; enable interrupts
	;;;;;BSF	INTCON, PEIE ; enable peripheral int
	BCF	INTCON, TMR0IF; clear flag
	BCF	INTCON, TMR0IE; disable tmr0 interrupt
	CLRF	TMR0; clear tmr0
	;;;;;BSF	INTCON, GIE  ; enable global int
	BCF	INTCON, GIE
	
;#############################################################################
;	Main
;#############################################################################

	CALL WAIT_50ms
MAIN:
	MOVLW	'T'
	CALL SEND_BYTE
	MOVLW	'M'
	CALL SEND_BYTE	
	MOVLW	'R'
	MOVLW	'0'
	CALL SEND_BYTE	
	
	MOVLW	0x0D
	CALL SEND_BYTE			
	MOVLW	0x0A
	CALL SEND_BYTE
	
;#############################################################################
;	Main Loop
;#############################################################################
	MOVLW	mask_TMR0
LOOP:
	XORWF	PORTB, F
	
	;CLRF	TMR0		; clear tmr0
	BCF	INTCON, TMR0IF	; clear flag
LOOPa:
	BTFSS	INTCON, TMR0IF
	GOTO	LOOPa
	
	GOTO	LOOP



;#############################################################################
;	SUB ROUTINES
;#############################################################################

; 	UART TX  
SEND_BYTE:	; send byte to UART, blocking
	BTFSS	PIR1, TXIF
	GOTO	SEND_BYTE
	MOVWF	TXREG
	RETURN
	
	
; 	Int to Hex nibble char table
table_nibbleHex:
	ADDWF	PCL, F
	dt	"0123456789ABCDEF"
	
;#############################################################################
;	Delay routines	for 8MHz
;	 at 8MHz intrc, 2Mips, 0.5us per instruction cycle
;#############################################################################
; 2 000 000 cycles
 
WAIT_1s:				; (2) call
	MOVLW	10			; (1) 10x 200 000
	MOVWF	WAIT_loopCounter1	; (1)
; 4 overhead
WAIT_1s_loop1:
	MOVLW	200			; (1) for 100 ms
	MOVWF	WAIT_loopCounter2	; (1)
; loop 1 overhead 5 * 200
WAIT_1s_loop2:			; 0.5ms / loop1
	MOVLW	250 - 2			; (1) 250 loops of 4 cycles (minus 2 loop for setup and next loop)
	MOVWF	WAIT_loopCounter3	; (1)
	GOTO 	$ + 1			; (2)	
; loop 2 overhead 7 * 248
WAIT_1s_loop3:			; 4 cycles per loop (2us / loop2)
	NOP				; (1)
	DECFSZ	WAIT_loopCounter3, F	; (1)
	GOTO	WAIT_1s_loop3		; (2)
	
	GOTO 	$ + 1			; (2)
	
	DECFSZ	WAIT_loopCounter2, F	; (1)
	GOTO	WAIT_1s_loop2		; (2)

	DECFSZ	WAIT_loopCounter1, F	; (1)
	GOTO	WAIT_1s_loop1		; (2)
	RETURN				; (2)
; 2 return


WAIT_50ms:;100006 cycles or 50.003 ms; (2) call
	MOVLW	100			; (1)
	MOVWF	WAIT_loopCounter1	; (1)
WAIT_50ms_loop1:			; 0.5ms / loop1
	MOVLW	199			; (1) 250 loops of 4 cycles (minus 2 loop for setup and next loop)
	MOVWF	WAIT_loopCounter2	; (1)
WAIT_50ms_loop2:			;  5 cycles per loop (2us / loop2)
	GOTO 	$ + 1			; (2)	
	DECFSZ	WAIT_loopCounter2, F	; (1)
	GOTO	WAIT_50ms_loop2	; (2)
	DECFSZ	WAIT_loopCounter1, F	; (1)
	GOTO	WAIT_50ms_loop1	; (2)
	RETURN				; (2)

WAIT_50us:				; (2) call is 2 cycle
	MOVLW	23			; (1) 100 instruction for 50 us, 1 == 10 cycles = 5us, 2 is 14, 3 is 18, 4 is 22
	MOVWF	WAIT_loopCounter1	; (1)
WAIT_50us_loop:
	NOP				; (1)
	DECFSZ	WAIT_loopCounter1, F	; (1)
	GOTO	WAIT_50us_loop		; (2)
	GOTO	$ + 1			; (2)
	RETURN				; (2)
	
WAIT_5us:				; (2) call is 2 cycle
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	RETURN				; (2) return is 2 cycle

;#############################################################################
;	End Declaration
;#############################################################################

	END

	
	
	
	
	
	
	
	
	
	
	
