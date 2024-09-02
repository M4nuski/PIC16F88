	LIST		p=16F88		; list directive to define processor
	#INCLUDE	<P16F88.INC>	; processor specific variable definitions
	#INCLUDE	<PIC16F88_Macro.asm>

; Bank #    SFR           GPR               SHARED GPR's
; Bank 0    0x00-0x1F     0x20-0x6F         0x70-0x7F    
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF

;#############################################################################
;	Configuration
;#############################################################################

	__CONFIG	_CONFIG1, 	_CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & _WDT_OFF & _HS_OSC
	__CONFIG	_CONFIG2, 	_IESO_OFF & _FCMEN_OFF

;Begin
	ORG     0x0000
	BCF	INTCON, GIE

	BANK1

	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	; 8mhz
	; 2 million instruction per sec

	CLRF	TRISA
	CLRF	TRISB
	BANK0

MAIN	NOP
	INCF	PORTB, F
	GOTO	MAIN
	; 500k loops per seconds
	; bit0 0-1 transition 250k/sec

	END
