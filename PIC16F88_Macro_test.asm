	LIST	p=16F88			; processor model
#INCLUDE	<P16F88.INC>		; processor specific variable definitions
#INCLUDE	<PIC16F88_Macro.asm>	; base macro for banks, context, branchs

F1	EQU	0x20
F2	EQU	0x24
F3	EQU	0x28
F4	EQU	0x2C
F5	EQU	0x30
F6	EQU	0x34
F7	EQU	0x38
F8	EQU	0x3C

	ORG	0x0000
	
	MOVLW	0x20	;start loc 0x20
	MOVWF	FSR
	MOVLW	0x20	;count 32
	MOVWF	0x7F
	MOVLW	0x99	;buzz content
buzzmem:
	MOVWF	INDF	
	INCF	FSR
	DECFSZ	0x7F
	GOTO buzzmem

	BANK0
	BANK1
	BANK2
	BANK3
	CLRF STATUS
	
	STR	0x00, F1
	STR	0xFF, F1
	
	STRs	0x1234, F2
	STRs	0x5678, F2
	
	STRc	0xAABBCC, F3
	STRc	0x112233, F3
	
	STRi	0xAABBCCDD, F4
	STRi	0x11223344, F4
	
	CLRF	F1
	CLRFs	F2
	CLRFc	F3
	CLRFi	F4
	
	MOVLW	0x00	
	NEGw
	NEG	F1
	NEGs	F2
	NEGc	F3
	NEGi	F4
	
	NEGw
	NEG	F1
	NEGs	F2
	NEGc	F3
	NEGi	F4
	
	MOVLW	0x00
	TEST_w
	MOVWF	F1
	TEST_f	F1

	MOVLW	0xFF
	TEST_w	
	MOVWF	F1
	TEST_f	F1
	
	TESTs_f	F2
	TESTc_f	F3
	TESTi_f	F4
	
	CLRFs	F2
	CLRFc	F3
	CLRFi	F4
	
	TESTs_f F2
	TESTc_f F3
	TESTi_f F4

LockLoop:
	GOTO LockLoop
	END
