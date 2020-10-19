;#############################################################################
;	PIC16F88 MACRO TEST 1
;	Test program for the the macro instructions:
;	BANK CLR STR NEG TEST COMP MOVE SWAP
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

;#############################################################################
;	Reset Vector - Main Entry Point
;#############################################################################

	ORG	0x0000
	
;#############################################################################
;	Interrupt Vector - Interrupt Service Routine
;#############################################################################
	; no interrupt so the ISR vector is never used
	;ORG	0x0004
	
	; fill memory with 0x99 to check for under/overflow
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
	
; ############################### BANK

	BANK0
	BANK1
	BANK2
	BANK3
	CLRF STATUS	

; ############################### STR
	NOP ; sect 1 STR, CLR, NEG
	
	STR	0x00, F1
	STR	0xFF, F1	
	ASSERTf	0xFF, F1
	ASSERTf	0x99, F1+1
	
	STRs	0x1234, F2
	STRs	0x5678, F2
	ASSERTs	0x5678, F2
	ASSERTf	0x99, F2+2
	
	STRc	0xAABBCC, F3
	STRc	0x112233, F3
	ASSERTc	0x112233, F3
	ASSERTf	0x99, F3+3
	
	STRi	0xAABBCCDD, F4
	STRi	0x11223344, F4
	ASSERTi	0x11223344, F4
	ASSERTf	0x99, F4+4
	
; ############################### CLRF
	CLRF	F1
	ASSERTf	0x00, F1
	ASSERTf	0x99, F1+1
	CLRFs	F2
	ASSERTs	0x0000, F2
	ASSERTf	0x99, F2+2
	CLRFc	F3
	ASSERTc	0x000000, F3
	ASSERTf	0x99, F3+3
	CLRFi	F4	
	ASSERTi	0x00000000, F4
	ASSERTf	0x99, F4+4

; ############################### NEG
	STR	0x12, F1
	STRs	0x1234, F2
	STRc	0x123456, F3
	STRi	0x12345678, F4
	
	NOP ;sect 1 negates
	
	MOVLW	0xAA
	NEGw
	ASSERTw	0x56
	NEG	F1
	ASSERTf	-0x12, F1
	NEGs	F2
	ASSERTs	-0x1234, F2
	NEGc	F3
	ASSERTc	-0x123456, F3
	NEGi	F4
	ASSERTi	-0x12345678, F4
	
	MOVLW	0x56
	NEGw
	ASSERTw	0xAA
	NEG	F1
	ASSERTf	0x12, F1
	NEGs	F2
	ASSERTs	0x1234, F2
	NEGc	F3
	ASSERTc	0x123456, F3
	NEGi	F4
	ASSERTi	0x12345678, F4
	
; ############################### TEST
	NOP
	NOP ; sect 2 tests
	
		
	MOVLW	0x00
	MOVWF	F1
	TESTw
	ASSERT_EQ
	TEST	F1
	ASSERT_EQ
	
	MOVLW	0xFF
	MOVWF	F1
	TESTw	
	ASSERT_NE
	TEST	F1
	ASSERT_NE
		
	TESTs	F2
	ASSERT_NE
	TESTc	F3
	ASSERT_NE
	TESTi	F4
	ASSERT_NE
	
	CLRFs	F2
	CLRFc	F3
	CLRFi	F4
	
	TESTs F2
	ASSERT_EQ
	TESTc F3
	ASSERT_EQ
	TESTi F4
	ASSERT_EQ
	
; ############################### COMP 8
	NOP
	NOP
	NOP ; sect 3 compares
	MOVLW	0x08 ; 8 bit
	
	; 8 bit
	STR	0x55, F1
	STR	0x54, F2
	STR	0x55, F3
	STR	0x56, F4
	
	; literal vs file
	
	COMP_l_f	0x55, F1	
	ASSERT_EQ
	ASSERT_LE
	ASSERT_GE
	
	COMP_l_f	0x56, F1	; 0x56 - 0x55 = 0x01, positive, not equal
	ASSERT_NE
	ASSERT_GT
	ASSERT_GE
	
	COMP_l_f	0x54, F1
	ASSERT_NE	
	ASSERT_LT
	ASSERT_LE
	
	; file vs file
	
	COMP_f_f	F3, F1
	ASSERT_EQ
	ASSERT_LE
	ASSERT_GE	

	COMP_f_f	F4, F1		
	ASSERT_NE
	ASSERT_GT
	ASSERT_GE

	COMP_f_f	F2, F1	
	ASSERT_NE	
	ASSERT_LT
	ASSERT_LE

	; file vs w
	
	MOVLW		0x55
	COMP_f_w	F1	
	ASSERT_EQ
	ASSERT_LE
	ASSERT_GE
	
	MOVLW		0x54
	COMP_f_w	F1
	ASSERT_NE
	ASSERT_GT
	ASSERT_GE
	
	MOVLW		0x56
	COMP_f_w	F1
	ASSERT_NE	
	ASSERT_LT
	ASSERT_LE
	
	; literal vs w
	
	MOVLW		0x55
	COMP_l_w	0x55	
	ASSERT_EQ
	ASSERT_LE
	ASSERT_GE
	
	MOVLW		0x55
	COMP_l_w	0x56
	ASSERT_NE
	ASSERT_GT
	ASSERT_GE
	
	MOVLW		0x55
	COMP_l_w	0x54
	ASSERT_NE	
	ASSERT_LT
	ASSERT_LE

	
; ############################### COMP 16
	NOP
	NOP
	NOP ; sect 3 compares
	MOVLW	0x16 ; 16 bit
	
	; 16 bit
	STRs	0x5FFF, F1
	STRs	0x5FFE, F2
	STRs	0x5FFF, F3
	STRs	0x6000, F4	
	
	; l vs f
	
	COMPs_l_f	0x5FFF, F1
	ASSERT_EQ
	ASSERT_LE
	ASSERT_GE	
	ASSERTs	0x5FFF, F1
		
	COMPs_l_f	0x6000, F1
	ASSERT_NE
	ASSERT_GT
	ASSERT_GE
	ASSERTs	0x5FFF, F1

	COMPs_l_f	0x5FFE, F1
	ASSERT_NE	
	ASSERT_LT
	ASSERT_LE
	ASSERTs	0x5FFF, F1
	
	; borrow on byte 0
	
	STRs	0x00FF, F6
	COMPs_l_f	0x00FE, F6
	ASSERT_NE	
	ASSERT_LT
	ASSERT_LE
	ASSERTs	0x00FF, F6
			
	; borrow on byte 1
	
	STRs	0xFF00, F6
	COMPs_l_f	0xFE00, F6
	ASSERT_NE	
	ASSERT_LT
	ASSERT_LE
	ASSERTs	0xFF00, F6	
		
	; borrow on byte 0 and 1
	
	STRs	0xFFFF, F6
	COMPs_l_f	0xFFFE, F6
	ASSERT_NE	
	ASSERT_LT
	ASSERT_LE
	ASSERTs	0xFFFF, F6	
		
	; borrow on byte 0 and 1
	
	STRs	0xFFFF, F6			
	COMPs_l_f	0x00FE, F6
	ASSERT_NE	
	ASSERT_LT
	ASSERT_LE
	ASSERTs	0xFFFF, F6	
		
	; f vs f
	
	COMPs_f_f	F3, F1	
	ASSERT_EQ
	ASSERT_LE
	ASSERT_GE
	ASSERTs	0x5FFF, F1
	ASSERTs	0x5FFF, F3
	
	COMPs_f_f	F4, F1
	ASSERT_NE
	ASSERT_GT
	ASSERT_GE
	ASSERTs	0x5FFF, F1
	ASSERTs	0x6000, F4
	
	COMPs_f_f	F2, F1
	ASSERT_NE	
	ASSERT_LT
	ASSERT_LE
	ASSERTs	0x5FFF, F1
	ASSERTs	0x5FFE, F2
	
	; borrow on byte 0
	
	STRs	0x00FE, F7
	STRs	0x00FF, F8
	COMPs_f_f	F7, F8	
	ASSERT_NE	
	ASSERT_LT
	ASSERT_LE		
	ASSERTs	0x00FE, F7
	ASSERTs	0x00FF, F8
	
	; borrow on byte 1
	
	STRs	0xFE00, F7
	STRs	0xFF00, F8	
	COMPs_f_f	F7, F8
	ASSERT_NE	
	ASSERT_LT
	ASSERT_LE
	ASSERTs	0xFE00, F7
	ASSERTs	0xFF00, F8
	
	; borrow on both byte
	
	STRs	0xFFFE, F7
	STRs	0xFFFF, F8		
	COMPs_f_f	F7, F8
	ASSERT_NE	
	ASSERT_LT
	ASSERT_LE
	ASSERTs	0xFFFE, F7
	ASSERTs	0xFFFF, F8


; ############################### COMP 24
	NOP
	NOP
	NOP ; sect 3 compares
	MOVLW	0x24 ; 24 bit
	
	
	
	
; ############################### COMP 32
	NOP
	NOP
	NOP ; sect 3 compares
	MOVLW	0x32 ; 32 bit
	
	STRi	0x55555555, F1
	STRi	0x55555554, F2
	STRi	0x55555555, F3
	STRi	0x55555556, F4
	
	STRi	0x5FFFFFFF, F1
	STRi	0x5FFFFFFE, F2
	STRi	0x5FFFFFFF, F3
	STRi	0x60000000, F4
	
; ############################### MOVE 8
	NOP
	NOP
	NOP
	NOP ; sect 4 MOVE
	MOVLW	0x08 ; 8 bit
; ############################### MOVE 16
	NOP
	NOP
	NOP
	NOP ; sect 4 MOVE
	MOVLW	0x16 ; 16 bit
; ############################### MOVE 24
	NOP
	NOP
	NOP
	NOP ; sect 4 MOVE
	MOVLW	0x24 ; 24 bit
; ############################### MOVE 32
	NOP
	NOP
	NOP
	NOP ; sect 4 MOVE
	MOVLW	0x32 ; 32 bit
	
	
; ############################### SWAP 8
	NOP
	NOP
	NOP
	NOP
	NOP ; sect 5 SWAP
	MOVLW	0x08 ; 8 bit
; ############################### SWAP 16
	NOP
	NOP
	NOP
	NOP
	NOP ; sect 5 SWAP
	MOVLW	0x16 ; 16 bit
; ############################### SWAP 24
	NOP
	NOP
	NOP
	NOP
	NOP ; sect 5 SWAP
	MOVLW	0x24 ; 24 bit
; ############################### SWAP 32
	NOP
	NOP
	NOP
	NOP
	NOP ; sect 5 SWAP
	MOVLW	0x32 ; 32 bit
	
	
	

; ############################### END
	GOTO $
	END
