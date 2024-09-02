	LIST		p=16F88		; list directive to define processor
	#INCLUDE	<P16F88.INC>	; processor specific variable definitions
	#INCLUDE	<PIC16F88_Macro.asm>

; Bank #    SFR           GPR               SHARED GPR's
; Bank 0    0x00-0x1F     0x20-0x6F         0x70-0x7F    
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF
;
; for baud rate testing, ________D10101010U
; 1 start 1 stop, 10 bauds per byte
; ext HS 18.432 MHZ, 9600 bauds, 4 608 000 instructions / s
; output is 9600 / 2 or 4800 Hz


;#############################################################################
;	Configuration
;#############################################################################

	__CONFIG	_CONFIG1, 	_CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & _WDT_OFF & _HS_OSC
	__CONFIG	_CONFIG2, 	_IESO_OFF & _FCMEN_OFF

; PIC16F88:
; pin  1 IOA PORTA2	O
; pin  2 IOA PORTA3	O 
; pin  3 IOA PORTA4	O
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O CLK div 16	250 000
; pin  7 IO_ PORTB1	O CLK div 32	125 000
; pin  8 IOR PORTB2	O CLK div 64	 62 500
; pin  9 IO_ PORTB3	O CLK div 128	 31 250

; pin 10 IO_ PORTB4	O CLK div 256	 16 625
; pin 11 IOT PORTB5	O CLK div 512	  7 812.5
; pin 12 IOA PORTB6	O ICSP PGC / CLK div 1024	3 906.25
; pin 13 IOA PORTB7	O ICSP PGD / CLK div 2048	1 953.125
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O 
; pin 16 I_X PORTA7	O 
; pin 17 IOA PORTA0	O 
; pin 18 IOA PORTA1	O 

count	EQU	0x20
loop	EQU	0x21

ISR:
	ORG     0x0000
	BCF	INTCON, GIE
	
SETUP:
	ORG	0x0004

	BANK1

	BCF	OSCCON, SCS0  ; Defined by FOSC in config
	BCF	OSCCON, SCS1
	;BSF	OSCCON, IRCF0 ; 8MHz internal rc clock
	;BSF	OSCCON, IRCF1
	;BSF	OSCCON, IRCF2	
SETUP_OSC:
	;BTFSS	OSCCON, IOFS
	;GOTO	SETUP_OSC

	MOVLW	0xFF
	MOVWF	TRISA	; all inputs
	CLRF	TRISB	; all outputs
	CLRF	ANSEL	; all digital
	
	BANK0
	
	CLRF	PORTB

MAIN:
	INCF	count, F
	MOVF	count, W
	MOVWF	PORTB
	
	;;GOTO	$+1; for10
	;;GOTO	$+1

	

	; MOVLW	8
	; MOVWF	loop
	; ;5
; WAIT:
	; NOP
	; DECFSZ	loop, F       ;4 per loop, *58 = 232, +8 = 240 for 9600, *8 = 32, +8 = 40 for 115200
	; GOTO	WAIT
	
	;;NOP ; for 5
	GOTO	MAIN
	; 8 per main loop
	
	
	; 4 instructions cycles per loop
	; 18.432 clock -> 2MIPS -> 500 000 increment clock -> B0 clock at 250 000
	END
