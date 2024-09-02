;#############################################################################
;
;	Test program for TIMER1 usability without interrupts
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
; pin  6 IO_ PORTB0	O Output XOR
; pin  7 IO_ PORTB1	
; pin  8 IOR PORTB2	
; pin  9 IO_ PORTB3	

; pin 10 IO_ PORTB4	
; pin 11 IOT PORTB5
; pin 12 IOA PORTB6	
; pin 13 IOA PORTB7	
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O ISR Status Bit
; pin 16 I_X PORTA7	
; pin 17 IOA PORTA0	
; pin 18 IOA PORTA1	


; V+ (square pad)
; Clock
; E
; Data
; GND

;#DEFINE 		PORTA, 0
;#DEFINE 		PORTA, 1
;#DEFINE 		PORTA, 2
;#DEFINE 		PORTA, 3
;#DEFINE 		PORTA, 4
;#DEFINE MCLR			PORTA, 5
#DEFINE bit_ISR		PORTA, 6
;#DEFINE 		PORTA, 7

#DEFINE bit_TMR		PORTB, 0
;#DEFINE 		PORTB, 1
;#DEFINE 		PORTB, 2
;#DEFINE 		PORTB, 3

;#DEFINE 		PORTB, 4
;#DEFINE 		PORTB, 5
;#DEFINE PGC			PORTB, 6
;#DEFINE PGD			PORTB, 7

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

x			EQU	0x20

WAIT_loopCounter1	EQU	0x30
WAIT_loopCounter2	EQU	0x31
WAIT_loopCounter3	EQU	0x32

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

ISR:
	BSF	bit_ISR
	BTFBS	PIR1, TMR1IF, ISR_T1	
	GOTO	ISR_END 		; unkown interrupt

ISR_T1:
	BCF	PIR1, TMR1IF
	GOTO	ISR	; ISR trap, code should be unreachable

ISR_END:
	BCF	bit_ISR

	POPfsr
	POP
	RETFIE

;#############################################################################
;	Initial Setup
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

	; peripheral interrupts
	BCF	PIE1, TMR1IE ; disable
	
	
	BANK0

	CLRF	TMR1L
	CLRF	TMR1H
	BCF	T1CON, T1CKPS0	; 
	BSF	T1CON, T1CKPS1	; 1:4, overflow every 131 ms
	BCF	T1CON, TMR1CS	; timer clock is FOSC/4
	BSF	T1CON, TMR1ON	; timer ON
	
	CLRF	PORTA
	CLRF	PORTB
	
	BCF	bit_ISR
	BCF	bit_TMR

; disable interrupts
	BCF	INTCON, PEIE ; peripheral int
	BCF	INTCON, GIE  ; global int
	

;#############################################################################
;	Main Loop
;#############################################################################

LOOP:	
	MOVLW	0x01
	XORWF	PORTB

	; reset TMR1
	CLRF	TMR1H
	CLRF	TMR1L
	BCF	PIR1, TMR1IF
LOOP_tmr:
	; test TMR1 for overflow
	BTFSS	PIR1, TMR1IF
	GOTO	LOOP_tmr
	GOTO	LOOP

	
;#############################################################################
;	End of main loop
;#############################################################################


;#############################################################################
;	Subroutines
;#############################################################################


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
