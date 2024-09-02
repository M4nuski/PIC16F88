;#############################################################################
;
;	TM1637 7 segment interface
;	8 modules X 6 digit per module
;	
;#############################################################################

;LIST	p=16F88			; processor model
;include	<P16F88.INC>		; processor specific variable definitions
#include <xc.inc>
;#include "macro.asm"	; base macro for banks, context, branchs


;#############################################################################
;	Configuration
;#############################################################################

config CP = OFF
config CCP1 = RB0
config DEBUG = OFF  
config WRT_PROTECT = OFF
config CPD = OFF 
config LVP = OFF 
config BODEN = OFF
config MCLR = ON
config PWRTE = OFF
config WDT = OFF
config INTRC = IO
config IESO = OFF
config FCMEN = OFF

;#############################################################################
;	Pinout
;#############################################################################

; PIC16F88:
; pin  1 IOA PORTA2	O Status INIT
; pin  2 IOA PORTA3	O Status MAIN
; pin  3 IOA PORTA4	O Status LOOP
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O Clock
; pin  7 IO_ PORTB1	O Data0
; pin  8 IOR PORTB2	O Data1
; pin  9 IO_ PORTB3	O Data2

; pin 10 IO_ PORTB4	I Data3
; pin 11 IOT PORTB5	I
; pin 12 IOA PORTB6	I ICSP PGC
; pin 13 IOA PORTB7	I ICSP PGD
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O Status ISR
; pin 16 I_X PORTA7	O 
; pin 17 IOA PORTA0	I 
; pin 18 IOA PORTA1	I


; VCC
; GND
; DIO
; CLK


;#DEFINE 		PORTA, 0
;#DEFINE 		PORTA, 1

#DEFINE Status_INIT	PORTA, 2
#DEFINE Status_MAIN	PORTA, 3
#DEFINE Status_LOOP	PORTA, 4
;MCLR			PORTA, 5
#DEFINE Status_ISR	PORTA, 6
;			PORTA, 7

#DEFINE Pin_Clock	PORTB, 0

#DEFINE Pin_Data0	PORTB, 1
#DEFINE Pin_Data1	PORTB, 2
#DEFINE Pin_Data2	PORTB, 3
#DEFINE Pin_Data3	PORTB, 4

;#DEFINE 		PORTB, 5
;PGC			PORTB, 6
;PGD			PORTB, 7



#DEFINE _Data_Write		01000000b
#DEFINE _Data_Read		01000010b
#DEFINE _Data_Address_Auto	01000000b
#DEFINE _Data_Address_Fixed	01000100b
#DEFINE _Data_Mode_Normal	01000000b
#DEFINE _Data_Mode_Test		01001000b

#DEFINE _Address_C0H		11000000b
#DEFINE _Address_C1H		11000001b
#DEFINE _Address_C2H		11000010b
#DEFINE _Address_C3H		11000011b
#DEFINE _Address_C4H		11000100b
#DEFINE _Address_C5H		11000101b

#DEFINE _Display_01_16	10000000b
#DEFINE _Display_02_16	10000001b
#DEFINE _Display_04_16	10000010b
#DEFINE _Display_10_16	10000011b
#DEFINE _Display_11_16	10000100b
#DEFINE _Display_12_16	10000101b
#DEFINE _Display_13_16	10000110b
#DEFINE _Display_14_16	10000111b

#DEFINE _Display_OFF	10000000b
#DEFINE _Display_ON	10001000b

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

Current_Display	EQU	0x23
Current_Value		EQU	0x24

char_buffer		EQU	0x25
bit_count		EQU	0x26

;#############################################################################
;	Macros
;#############################################################################


	
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
	;PUSHscr	;SCRATCH	
	BSF	Status_ISR
	
	BTFBS	PIR1, TMR1IF, ISR_T1
	
	GOTO	ISR_END 		; unkown interrupt

ISR_T1:
	BCF	PIR1, TMR1IF
	STR	228, TMR1H	;240 is 3.8Hz (?)

ISR_END:
	BCF	Status_ISR
	;POPscr
	POPfsr
	POP
	RETFIE

;#############################################################################
;	Initial Setup
;#############################################################################

SETUP:
	CLRF	PORTA
	CLRF	PORTB

	BANK1

	; init port directions
	CLRF	TRISA		; all outputs
	CLRF	TRISB		; all outputs
	
	; init analog inputs
	CLRF	ANSEL		; all digital

	BANK0
	BSF	Status_INIT
	BANK1
	
	; init osc 8MHz
	BCF	OSCCON, SCS0
	BCF	OSCCON, SCS1
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
WAIT_OSC:
	BTFSS	OSCCON, IOFS
	GOTO	WAIT_OSC

	BANK0
	
	; at 8x prescaler, 8mhz crystal, 2mhz instruction clock, 3.8hz timer1 overflow
	CLRF	TMR1L
	CLRF	TMR1H
	BCF	T1CON, T1CKPS0	; 
	BCF	T1CON, T1CKPS1	;
	BCF	T1CON, TMR1CS	; timer clock is FOSC/4
	BSF	T1CON, TMR1ON	; timer ON

	MOVLW	0xFF
	MOVWF	PORTB	; all high

; disable interrupts
	BCF	INTCON, PEIE ; peripheral int
	BCF	INTCON, GIE  ; global int
	
	;GOTO	MAIN

;#############################################################################
;	Display Initialization
;#############################################################################
MAIN:
	BSF	Status_MAIN
	
	;STR	1, Current_Display
	;CLRF	Current_Value

	CALL	TM1637_start
	MOVLW	(_Display_ON | _Display_10_16)
	MOVWF	char_buffer
	CALL	TM1637_data
	CALL	TM1637_stop
	
	
LOOP:
	CALL	TM1637_start
	MOVLW	_Data_Write
	MOVWF	char_buffer
	CALL	TM1637_data
	CALL	TM1637_stop
	
	CALL	TM1637_start
	MOVLW	_Address_C3H
	MOVWF	char_buffer
	CALL	TM1637_data
	
	;ARRAYl	table_hex, 0
	MOVLW	b'00111111'
	MOVWF	char_buffer
	CALL	TM1637_data
	
	;;ARRAYl	table_hex, 1
	MOVLW	b'00000110';1
	MOVWF	char_buffer
	CALL	TM1637_data
	
	;ARRAYl	table_hex, 2
	MOVLW	b'01011011';2
	MOVWF	char_buffer
	CALL	TM1637_data
	
	;ARRAYl	table_hex, 3
	MOVLW	b'01001111';3
	MOVWF	char_buffer
	CALL	TM1637_data
	
	;ARRAYl	table_hex, 4
	MOVLW	 b'01100110';4
	MOVWF	char_buffer
	CALL	TM1637_data
	
	;ARRAYl	table_hex, 5
	MOVLW	b'01101101';5
	MOVWF	char_buffer
	CALL	TM1637_data	
	CALL	TM1637_stop
          
	  

		
;	GOTO	LOOP


;#############################################################################
;	Main Loop
;#############################################################################



	BSF	Status_LOOP
	CALL	WAIT_50ms
	BCF	Status_LOOP
	CALL	WAIT_50ms
	
	GOTO	LOOP

	
;#############################################################################
;	End of main loop
;#############################################################################


	
;#############################################################################
;	Subroutines
;#############################################################################

TM1637_start:
	BCF	Pin_Data0	; data low
	CALL 	WAIT_50us
	RETURN
	
TM1637_data:	; data is in file "char_buffer"
	MOVLW	8
	MOVWF	bit_count
TM1637_dataLoop:
	NOP
	BCF	Pin_Clock	; clock low	
	CALL 	WAIT_50us
	
	BCF	Pin_Data0
	BTFSC	char_buffer, 0
	BSF	Pin_Data0
	CALL 	WAIT_50us
	
	BSF	Pin_Clock	; clock high
	CALL 	WAIT_50us
	
	RRF	char_buffer, F
	DECFSZ	bit_count, F
	GOTO	TM1637_dataLoop

	; ACK
	BCF	Pin_Clock	; clock low	
	BSF	Pin_Data0	; data high
	CALL 	WAIT_50us
	
	BSF	Pin_Clock	; clock high
	CALL 	WAIT_50us

	BCF	Pin_Clock	; clock low
	BCF	Pin_Data0	; data low
	CALL 	WAIT_50us	
	RETURN

TM1637_stop:
	BCF	Pin_Data0	; data low
	CALL 	WAIT_50us
	BSF	Pin_Clock	; clock high
	CALL 	WAIT_50us
	BSF	Pin_Data0	; data high
	CALL 	WAIT_50us
	RETURN


;#############################################################################
;	Tables
;#############################################################################

	PC0x0100SKIP; align to next 256 byte boundary in program memory

; 	Int to Hex nibble char table
table_hex:
	ADDWF	PCL, F
	RETLW	  b'00111111';0
	RETLW	  b'00000110';1
	RETLW	  b'01011011';2
 	RETLW	  b'01001111';3
	RETLW	  b'01100110';4
 	RETLW	  b'01101101';5
	RETLW	  b'01111101';6
 	RETLW	  b'00000111';7
 	RETLW	  b'01111111';8
 	RETLW	  b'01101111';9
 	RETLW	  b'01110111';A
 	RETLW	  b'01111100';b
 	RETLW	  b'00111001';C
 	RETLW	  b'01011110';d
 	RETLW	  b'01111001';E
 	RETLW	  b'01110001';F


;#############################################################################
;	PC 0x800 (1k) boundary
;#############################################################################

	;PC0x0800SKIP

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


WAIT_50ms:
	MOVLW	100			; (1) for 50 ms
	MOVWF	WAIT_loopCounter1	; (1)

WAIT_50ms_loop1:			; 0.5ms / loop1
	MOVLW	250 - 2			; (1) 250 loops of 4 cycles (minus 2 loop for setup and next loop)
	MOVWF	WAIT_loopCounter2	; (1)
	NOP				; (1)
	NOP				; (1)

WAIT_50ms_loop2:			; 4 cycles per loop (2us / loop2)
	NOP				; (1)
	DECFSZ	WAIT_loopCounter2, F	; (1)
	GOTO	WAIT_50ms_loop2	; (2)
	NOP				; (1)

	NOP				; (1)
	DECFSZ	WAIT_loopCounter1, F	; (1)
	GOTO	WAIT_50ms_loop1	; (2)

	RETURN
	
; at 8MHz intrc, 2Mips, 0.5us per instruction cycle
; call and setup is 4 cycles
; 23 loops is 23 * 4 = 92 cycles
; nop and return is 4 cycles
; total 100 cycles = 50us

WAIT_50us:				; (2) call is 2 cycle
	MOVLW	2			; (1) 100 instruction for 50 us, 1 == 10 cycles = 5us, 2 is 14, 3 is 18, 4 is 22
	MOVWF	WAIT_loopCounter1	; (1)
WAIT_50us_loop:
	NOP				; (1)
	DECFSZ	WAIT_loopCounter1, F	; (1)
	GOTO	WAIT_50ms_loop1	; (2)

	NOP				; (1)
	NOP				; (1)
	RETURN				; (2)

;#############################################################################
;	End Declaration
;#############################################################################

	END



