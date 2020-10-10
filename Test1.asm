	LIST	p=16F88		;Processor
	#INCLUDE <p16F88.inc>	;Processor Specific Registers
	#INCLUDE <PIC16F88_Macro.asm>
	
	__CONFIG	_CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_OFF & _PWRTE_OFF & _WDT_OFF & _INTRC_IO
	__CONFIG	_CONFIG2, _IESO_OFF & _FCMEN_OFF

; Bank #    SFR           GPR               SHARED GPR's
; Bank 0    0x00-0x1F     0x20-0x6F         0x70-0x7F    
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF

	ORG	0x0000
	BANK0
	BCF	INTCON, GIE	; clear global interrupts

	BANK1
	
	BCF	OSCCON, IRCF0
	BCF	OSCCON, IRCF1	
	BCF	OSCCON, IRCF2	
	
	CLRF PORTA
	CLRF PORTB

	BANK0

	CLRF PORTA
	CLRF PORTB
	
loop	
	INCFSZ PORTB, F
	GOTO incA
	NOP
	NOP
	NOP
	NOP
	GOTO loop
	
incA
	INCF PORTA, F
	NOP
	NOP
	GOTO loop
	
	END
	
	

	
	
	