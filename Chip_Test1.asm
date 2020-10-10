	LIST		p=16F88		; list directive to define processor
	#INCLUDE	<P16F88.INC>	; processor specific variable definitions
	#INCLUDE	<PIC16F88_Macro.asm>

; Bank #    SFR           GPR               SHARED GPR's
; Bank 0    0x00-0x1F     0x20-0x6F         0x70-0x7F    
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF

;Begin
	ORG     0x0000
	;BCF	INTCON, GIE

	;BANK1

	;BCF	OSCCON, IRCF0
	;BCF	OSCCON, IRCF1
	;BCF	OSCCON, IRCF2

	CLRF	TRISA
	CLRF	TRISB
	;BANK0

MAIN	ADDLW	0X01
	MOVWF	PORTA
	NOP
	NOP
	NOP
	MOVWF	PORTB
	GOTO	MAIN

	END
