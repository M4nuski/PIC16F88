	LIST	p=16F88			; processor model
#INCLUDE	<P16F88.INC>		; processor specific variable definitions

;#############################################################################
;	Configuration	
;#############################################################################

	__CONFIG	_CONFIG1, 	_CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & _WDT_OFF & _INTRC_IO					
	__CONFIG	_CONFIG2, 	_IESO_OFF & _FCMEN_OFF

;#############################################################################
;	MACRO
;#############################################################################
	
data_H10		EQU	0x29
data_H01		EQU	0x2A
data_m10		EQU	0x2B
data_m01		EQU	0x2C
data_s10		EQU	0x2D
data_s01		EQU	0x2E

	ORG	0x0000

	ORG	0x0004
	
	MOVLW	0x02
	MOVWF	data_H10
	MOVLW	0x03
	MOVWF	data_H01
	
	BCF	STATUS, C
	RLF	data_H10, F ; h10  = 2*h10
	MOVF	data_H10, W ; w = 2*h10
	BCF	STATUS, C
	RLF	data_H10, F ; h10  = 4*h10
	RLF	data_H10, F ; h10  = 8*h10
	ADDWF	data_H10, W
	
	ADDWF	data_H01, F ; h01 = 10*h10 + h01 = HH(utc)
	
	GOTO	$
	
	END
