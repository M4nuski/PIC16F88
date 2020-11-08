;#############################################################################
;	PIC16F88 Test Macro
;	Premade header
;	#INCLUDE	<PIC16F88_Macro_Tester.asm> at the begining of the file to setup mcu, config, vars and org
;	Instruction Counter
;	Assert:
;		w, bit set, bit cleared, file content
;#############################################################################

;#############################################################################
;	Standard header for PIC16F88
;#############################################################################

	LIST	p=16F88			; processor model
#INCLUDE	<P16F88.INC>		; processor specific variable definitions
#INCLUDE	<PIC16F88_Macro.asm>	; base macro for banks, context, branchs

	__CONFIG	_CONFIG1, 	_CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & 				_WDT_OFF & _INTRC_IO
	__CONFIG	_CONFIG2, 	_IESO_OFF & _FCMEN_OFF	
	
var1		EQU	0x20
var2		EQU	0x24
var3		EQU	0x28
var4		EQU	0x2C
var5		EQU	0x30
var6		EQU	0x34
var7		EQU	0x38
var8		EQU	0x3C

	ORG	0x0000
	CLRF	INTCON
	; no interrupt so the ISR vector is never used

;#############################################################################
;	Standard footer for PIC16F88
;#############################################################################

Test_Footer	MACRO
	GOTO	$
	END
	ENDM



;#############################################################################
;	Fill memory with know data to check for spurious writes
;#############################################################################

Test_FillMem	MACRO	startFile, Count, Content
	LOCAL	_loop
	MOVLW	startFile
	MOVWF	FSR
	MOVLW	Count
	MOVWF	var1
	MOVLW	Content		
_loop:
	MOVWF	INDF	
	INCF	FSR, F
	DECFSZ	var1, F
	GOTO	_loop
	ENDM



;#############################################################################
;	Instruction Counter using Timer1
;#############################################################################

Test_StartCounter	MACRO Prescale
	IF	Prescale == 1
	BCF	T1CON, T1CKPS0
	BCF	T1CON, T1CKPS1
	ENDIF
	IF	Prescale == 2
	BSF	T1CON, T1CKPS0
	BCF	T1CON, T1CKPS1
	ENDIF
	IF	Prescale == 4
	BCF	T1CON, T1CKPS0
	BSF	T1CON, T1CKPS1
	ENDIF
	IF	Prescale == 8
	BSF	T1CON, T1CKPS0
	BSF	T1CON, T1CKPS1
	ENDIF	
	BSF	STATUS, RP0
	BSF	PIE1, TMR1IE
	BCF	STATUS, RP0
	CLRF	TMR1H
	CLRF	TMR1L
	BSF	T1CON, TMR1ON
	ENDM
	
Test_StopCounter	MACRO Dest
	BCF	T1CON, TMR1ON
	BTFSC	PIR1, TMR1IF	; check for overflow
	STALL		
	MOVF	TMR1L, W
	MOVWF	Dest
	MOVF	TMR1H, W 
	MOVWF	Dest + 1	
	BSF	STATUS, RP0
	BCF	PIE1, TMR1IE
	BCF	STATUS, RP0		
	ENDM



;#############################################################################
;	Assertion macro for skip
;#############################################################################

ASSERT_SKIPPED		MACRO
	STALL
	ENDM
	
ASSERT_NOT_SKIPPED	MACRO
	GOTO	$ + 2
	STALL
	ENDM
	
;#############################################################################
;	Assertion macro for values
;#############################################################################

ASSERTw		MACRO val		; w == val
	XORLW	val
	BTFSS	STATUS, Z
	STALL
	XORLW	val
	ENDM
	
ASSERTbs	MACRO file, bit	; file bit is set
	BTFSS	file, bit
	STALL
	ENDM
	
ASSERTbc	MACRO file, bit	; file bit is cleared
	BTFSC	file, bit
	STALL
	ENDM
	
ASSERTf		MACRO	val, file	; val == file content
	MOVLW	val
	XORWF	file, W
	BTFSS	STATUS, Z
	STALL
	ENDM



;#############################################################################
;	Assertion macro for Status/Result
;#############################################################################

ASSERT_ZE	MACRO
	LOCAL	_END
	BR_ZE	_END
	STALL
_END:	
	ENDM	
ASSERT_NZ	MACRO
	LOCAL	_END
	BR_NZ	_END
	STALL
_END:	
	ENDM
ASSERT_EQ	MACRO
	LOCAL	_END
	BR_EQ	_END
	STALL
_END:	
	ENDM
ASSERT_NE	MACRO
	LOCAL	_END
	BR_NE	_END
	STALL
_END:	
	ENDM
ASSERT_GT	MACRO
	LOCAL	_END
	BR_GT	_END
	STALL
_END:	
	ENDM
ASSERT_GE	MACRO
	LOCAL	_END
	BR_GE	_END
	STALL
_END:	
	ENDM
ASSERT_LT	MACRO
	LOCAL	_END
	BR_LT	_END
	STALL
_END:	
	ENDM
ASSERT_LE	MACRO
	LOCAL	_END
	BR_LE	_END
	STALL
_END:	
	ENDM
ASSERT_CA	MACRO
	LOCAL	_END
	BR_CA	_END
	STALL
_END:	
	ENDM
ASSERT_NC	MACRO
	LOCAL	_END
	BR_NC	_END
	STALL
_END:	
	ENDM
ASSERT_BO	MACRO
	LOCAL	_END
	BR_BO	_END
	STALL
_END:	
	ENDM
ASSERT_NB	MACRO
	LOCAL	_END
	BR_NB	_END
	STALL
_END:	
	ENDM



;#############################################################################
;	Assertion macro for for 16, 24 and 32 bits values
;#############################################################################

ASSERTs		MACRO	val, file	; 16 bit val == file content
	MOVLW	(val & 0x000000FF) >> 0
	XORWF	file, W
	BTFSS	STATUS, Z
	STALL
	
	MOVLW	(val & 0x0000FF00) >> 8
	XORWF	file + 1, W
	BTFSS	STATUS, Z
	STALL
	ENDM
	
ASSERTc		MACRO	val, file	; 24 bit val == file content
	MOVLW	(val & 0x000000FF) >> 0
	XORWF	file, W
	BTFSS	STATUS, Z
	STALL
	
	MOVLW	(val & 0x0000FF00) >> 8
	XORWF	file + 1, W
	BTFSS	STATUS, Z
	STALL
	
	MOVLW	(val & 0x00FF0000) >> 16
	XORWF	file + 2, W
	BTFSS	STATUS, Z
	STALL
	ENDM
	
ASSERTi		MACRO	val, file	; 32 bit val == file content
	MOVLW	(val & 0x000000FF) >> 0
	XORWF	file, W
	BTFSS	STATUS, Z
	STALL
	
	MOVLW	(val & 0x0000FF00) >> 8
	XORWF	file + 1, W
	BTFSS	STATUS, Z
	STALL
	
	MOVLW	(val & 0x00FF0000) >> 16
	XORWF	file + 2, W
	BTFSS	STATUS, Z
	STALL

	MOVLW	(val & 0xFF000000) >> 24
	XORWF	file + 3, W
	BTFSS	STATUS, Z
	STALL
	ENDM



	
	
	
	
	
	
	