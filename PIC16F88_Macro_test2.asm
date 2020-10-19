;#############################################################################
;	PIC16F88 MACRO TEST 2
;	Test program for the the PIC16F88 MACRO
;	MOVE SWAP ADD ADDL SUB SUBL SUBF SUBFL INCF DECF
;#############################################################################

	LIST	p=16F88			 ; processor model
#INCLUDE	<P16F88.INC>		 ; processor specific variable definitions
#INCLUDE	<PIC16F88_Macro.asm>	 ; base macro for banks, context, branchs
#INCLUDE	<PIC16F88_MacroExt.asm>; macro for 16, 24 and 32 bit instructions

;#############################################################################
;	Configuration	
;#############################################################################

	__CONFIG	_CONFIG1, 	_CP_OFF &_CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & 				_WDT_OFF & _INTRC_IO
	__CONFIG	_CONFIG2, 	_IESO_OFF & _FCMEN_OFF	
	
;#############################################################################
;	Pinout
;#############################################################################

; No pinout as this is a debugger / emulator only program

;#############################################################################
;	File Variables and Constants
;#############################################################################

; 32 bit test files
F1	EQU	0x20 ; 1 2 3
F2	EQU	0x24 ; 5 6 7
F3	EQU	0x28 ; 9 A B
F4	EQU	0x2C ; D E F
F5	EQU	0x30 ; 1 2 3
F6	EQU	0x34 ; 5 6 7
F7	EQU	0x38 ; 9 A B
F8	EQU	0x3C ; D E F

; compare result test file location and bit definition
COMPresult 	EQU	0x40
COMP_EQ		EQU 	0
COMP_NE		EQU	1
COMP_LT		EQU	2
COMP_LE		EQU	3
COMP_GT		EQU	4
COMP_GE		EQU	5

;#############################################################################
;	Macro Definitions
;#############################################################################

READ_COMP_RES	MACRO
	LOCAL	EQ, NE, LT, LE, GT, GE, _end , _EQ, _NE, _LT, _LE, _GT, _GE
	
	BR_EQ	EQ	
_EQ:
	BR_NE	NE

_NE:
	BR_LT	LT
_LT:
	BR_LE	LE
	
_LE:
	BR_GT	GT
_GT:
	BR_GE	GE
	
_GE:
	GOTO	_end	
	
EQ:
	BSF	COMPresult, COMP_EQ
	GOTO 	_EQ
NE:
	BSF	COMPresult, COMP_NE
	GOTO 	_NE
LT:
	BSF	COMPresult, COMP_LT
	GOTO 	_LT
LE:
	BSF	COMPresult, COMP_LE
	GOTO 	_LE
GT:
	BSF	COMPresult, COMP_GT
	GOTO 	_GT
GE:
	BSF	COMPresult, COMP_GE
	GOTO 	_GE
_end:
	ENDM
	
;#############################################################################
;	Reset Vector - Main Entry Point
;#############################################################################

	ORG	0x0000
	
;#############################################################################
;	Interrupt Vector - Interrupt Service Routine
;#############################################################################
	; no interrupt so the ISR vector is never used
	;ORG	0x0004
	
	MOVLW	0x20	;start loc 0x20
	MOVWF	FSR
	MOVLW	0x40	;count 64
	MOVWF	0x7F
	MOVLW	0x99	;buzz content
	
buzzmem:
	MOVWF	INDF	
	INCF	FSR, F
	DECFSZ	0x7F, F
	GOTO buzzmem

	BANK0
	BANK1
	BANK2
	BANK3
	CLRF STATUS
	
	NOP ; sect 1 

; ############################### ADD 8
	NOP
	NOP
	NOP
	NOP ; sect 4 add
	MOVLW	0x08 ; 8 bit
	
; ############################### ADD 16
	NOP
	NOP
	NOP
	NOP ; sect 4 add
	MOVLW	0x16 ; 16 bit
	
; ############################### ADD 24
	NOP
	NOP
	NOP
	NOP ; sect 4 add
	MOVLW	0x24 ; 24 bit
	
; ############################### ADD 32
	NOP
	NOP
	NOP
	NOP ; sect 4 add
	MOVLW	0x32 ; 32 bit
	
	
	
; ############################### SUB 8
	NOP
	NOP
	NOP
	NOP ; sect 4 sub
	MOVLW	0x08 ; 8 bit
	
; ############################### SUB 16
	NOP
	NOP
	NOP
	NOP ; sect 4 sub
	MOVLW	0x61 ; 16 bit
	
; ############################### SUB 24
	NOP
	NOP
	NOP
	NOP ; sect 4 sub
	MOVLW	0x42 ; 24 bit
	
; ############################### SUB 32
	NOP
	NOP
	NOP
	NOP ; sect 4 sub
	MOVLW	0x23 ; 32 bit
	





; ############################### INC 16
	NOP
	NOP
	NOP
	NOP
	NOP ; sect 5 inc
	MOVLW	0x16 ; 16 bit
	
	
; ############################### INC 24
	NOP
	NOP
	NOP
	NOP
	NOP ; sect 5 inc
	MOVLW	0x24 ; 24 bit
	
; ############################### INC 32
	NOP
	NOP
	NOP
	NOP
	NOP ; sect 5 inc
	MOVLW	0x32 ; 32 bit
	
	
	
; ############################### DEC 16
	NOP
	NOP
	NOP
	NOP
	NOP ; sect 5 dec
	MOVLW	0x61 ; 16 bit
	
	
	
; ############################### DEC 24
	NOP
	NOP
	NOP
	NOP
	NOP ; sect 5 inc
	MOVLW	0x42 ; 24 bit
	
	
	
; ############################### DEC 32
	NOP
	NOP
	NOP
	NOP
	NOP ; sect 5 inc
	MOVLW	0x23 ; 32 bit
	
	
	
	
	
; ############################### ADDL 8
	NOP
	NOP
	NOP
	
	NOP
	NOP	
	NOP ; sect 6 addlit	
	MOVLW	0x08 ; 8 bit
	
; ############################### ADDL 16
	NOP
	NOP
	NOP
	
	NOP
	NOP	
	NOP ; sect 6 addlit
	MOVLW	0x16 ; 16 bit
	
; ############################### ADDL 24
	NOP
	NOP
	NOP
	
	NOP
	NOP	
	NOP ; sect 6 addlit
	MOVLW	0x24 ; 24 bit
	
; ############################### ADDL 32
	NOP
	NOP
	NOP
	
	NOP
	NOP	
	NOP ; sect 6 addlit
	MOVLW	0x32 ; 32 bit
	
	
; ############################### SUBL 8
	NOP
	NOP
	NOP
	
	NOP
	NOP	
	NOP ; sect 6 sublit
	MOVLW	0x80 ; 8 bit	
	
; ############################### SUBL 16
	NOP
	NOP
	NOP
	
	NOP
	NOP	
	NOP ; sect 6 sublit
	MOVLW	0x61 ; 16 bit
	
; ############################### SUBL 24
	NOP
	NOP
	NOP
	
	NOP
	NOP	
	NOP ; sect 6 sublit
	MOVLW	0x42 ; 24 bit
	
; ############################### SUBL 32
	NOP
	NOP
	NOP
	
	NOP
	NOP	
	NOP ; sect 6 sublit
	MOVLW	0x23 ; 32 bit	
	
; ###############################
	GOTO $
	END
