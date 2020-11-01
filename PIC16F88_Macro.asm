;#############################################################################
;	PIC16F88 MACRO
;	Basic macros for PIC16F88
;
;	BANK Switching
;	TEST and CMP
;	Conditionals BRanchs, CAlls and SKips
;	Bit Tests conditionals BRanchs, CAlls and SKips
;	8 bit file on file instructions:
;		STR, NEG, MOV, SWAP, ADD, ADDL, SUB, SUBL, SUBF, SUBFL 
;	ISR context switching:
;		W + STATUS + PCLATH, FSR, SCRATCH
;	Timer1 value reader
;	Assert:
;		w, bit set, bit cleared, file
;#############################################################################



;#############################################################################
;	Bank Switching
;#############################################################################

BANK0	MACRO
	BCF	STATUS, RP0
	BCF	STATUS, RP1
	ENDM

BANK1	MACRO
	BSF	STATUS, RP0
	BCF	STATUS, RP1
	ENDM

BANK2	MACRO
	BCF	STATUS, RP0
	BSF	STATUS, RP1
	ENDM

BANK3	MACRO
	BSF	STATUS, RP0
	BSF	STATUS, RP1
	ENDM
	
	
	
;#############################################################################
;	Tests
; 	 check if target is Zero (Result is STATUS Z)
;#############################################################################

TEST	MACRO	file
	MOVF	file, F
	ENDM
	
TESTw	MACRO
	ANDLW	0xFF
	ENDM
	
	
	
;#############################################################################
;	Comparaison
; 	 a vs b (Result is STATUS Z and C)
;#############################################################################

CMP_lf	MACRO lit, file	; literal vs file
	MOVF	file, W			; w = f
	SUBLW	lit			; w = l - f(w)
	ENDM
	
CMP_ff	MACRO file1, file2	; file1 vs file2
	MOVF	file2, W		; w = f2
	SUBWF	file1, W		; w = f1 - f2(w)
	ENDM

CMP_fw	MACRO file		; file vs w
	SUBWF	file, W			; w = f - w
	ENDM

CMP_lw	MACRO lit		; literal vs w
	SUBLW	lit			; w = l - w
	ENDM
	
	
	
;#############################################################################
;	Branch
;	EQual, NotEqual
;	Greater Than, Greater or Equal
;	Less Than, Less or Equal
;	ZEro, Not Zero
;	CArry, No Carry
;	BOrrow, No Borrow
;#############################################################################
; from test and comp result
BR_EQ	MACRO	dest
	BTFSC	STATUS, Z
	GOTO	dest
	ENDM
	
BR_NE	MACRO	dest
	BTFSS	STATUS, Z
	GOTO	dest
	ENDM

BR_GT	MACRO 	dest
	LOCAL	_end
	BTFSC	STATUS, Z	; first test that not equal
	GOTO	_end
	BTFSC	STATUS, C	; skip goto if there was no carry (greater)
	GOTO	dest
_end:
	ENDM

BR_GE	MACRO 	dest
	BTFSC	STATUS, C
	GOTO	dest
	BTFSC	STATUS, Z
	GOTO	dest
	ENDM
	
BR_LT	MACRO	dest
	LOCAL	_end
	BTFSC	STATUS, Z	; test that not equal
	GOTO	_end
	BTFSS	STATUS, C	; skip if there was a carry (less)
	GOTO	dest
_end:
	ENDM

BR_LE	MACRO 	dest
	BTFSS	STATUS, C
	GOTO	dest
	BTFSC	STATUS, Z
	GOTO	dest
	ENDM
	
; from status state
BR_ZE	MACRO	dest	; zero
	BTFSC	STATUS, Z
	GOTO	dest
	ENDM
	
BR_NZ	MACRO	dest	; not zero
	BTFSS	STATUS, Z
	GOTO	dest
	ENDM
	
BR_CA	MACRO	dest	; carry
	BTFSC	STATUS, C
	GOTO	dest
	ENDM	
	
BR_NC	MACRO	dest	; no carry
	BTFSS	STATUS, C
	GOTO	dest
	ENDM

BR_BO	MACRO	dest	; borrow
	BTFSS	STATUS, C
	GOTO	dest
	ENDM
	
BR_NB	MACRO	dest	; no borrow
	BTFSC	STATUS, C
	GOTO	dest
	ENDM
	
	
;#############################################################################
;	Call
;#############################################################################

; from test and comp result
CALL_EQ	MACRO	dest
	BTFSC	STATUS, Z
	CALL	dest
	ENDM
	
CALL_NE	MACRO	dest
	BTFSS	STATUS, Z
	CALL	dest
	ENDM

CALL_GT	MACRO 	dest
	LOCAL	_end
	BTFSC	STATUS, Z	; first test for not equal
	GOTO	_end
	BTFSC	STATUS, C	; skip call if there was no borrow
	CALL	dest
_end:
	ENDM

CALL_GE	MACRO 	dest
	LOCAL	_call
	BTFSC	STATUS, Z
	GOTO	_call
	BTFSC	STATUS, C
_call:	
	CALL	dest
	ENDM
	
CALL_LT	MACRO	dest
	LOCAL	_end
	BTFSC	STATUS, Z	; test that not equal
	GOTO	_end
	BTFSS	STATUS, C	; skip if there was a carry (less)
	CALL	dest
_end:
	ENDM

CALL_LE	MACRO 	dest
	LOCAL	_call
	BTFSC	STATUS, Z
	GOTO	_call
	BTFSS	STATUS, C
_call:
	CALL	dest
	ENDM

; from status state
CALL_ZE	MACRO	dest	; zero
	BTFSC	STATUS, Z
	CALL	dest
	ENDM
	
CALL_NZ	MACRO	dest	; not zero
	BTFSS	STATUS, Z
	CALL	dest
	ENDM
	
CALL_CA	MACRO	dest	; carry
	BTFSC	STATUS, C
	CALL	dest
	ENDM	
	
CALL_NC	MACRO	dest	; no carry
	BTFSS	STATUS, C
	CALL	dest
	ENDM

CALL_BO	MACRO	dest	; borrow
	BTFSS	STATUS, C
	CALL	dest
	ENDM
	
CALL_NB	MACRO	dest	; no borrow
	BTFSC	STATUS, C
	CALL	dest
	ENDM
	
	
;#############################################################################
;	Skip next instruction
;#############################################################################

SK_ZE	MACRO
	BTFSS	STATUS, Z
	ENDM	

SK_NZ	MACRO
	BTFSC	STATUS, Z
	ENDM
	
SK_EQ	MACRO
	BTFSS	STATUS, Z
	ENDM	

SK_NE	MACRO
	BTFSC	STATUS, Z
	ENDM

SK_CA	MACRO
	BTFSS	STATUS, C
	ENDM	

SK_NC	MACRO
	BTFSC	STATUS, C
	ENDM

SK_BO	MACRO
	BTFSC	STATUS, C
	ENDM	

SK_NB	MACRO
	BTFSS	STATUS, C
	ENDM



;#############################################################################
;	Bit test File and Branch
;#############################################################################

BTFBS	MACRO	file, bit, dest	; brach if set
	BTFSC	file, bit
	GOTO	dest
	ENDM
	
BTFBC	MACRO	file, bit, dest	; branch if clear
	BTFSS	file, bit
	GOTO	dest
	ENDM



;#############################################################################
;	Bit test File and CALL
;#############################################################################

BTFCS	MACRO	file, bit, dest	; call if set
	BTFSC	file, bit
	CALL	dest
	ENDM
	
BTFCC	MACRO	file, bit, dest	; call if clear
	BTFSS	file, bit
	CALL	dest
	ENDM
	
	
	
;#############################################################################
;	Bit test W and Branch
;#############################################################################

BTWBS	MACRO	bit, dest		; branch if set
	MOVWF	SCRATCH
	BTFSC	SCRATCH, bit
	GOTO	dest
	ENDM
	
BTWBC	MACRO	bit, dest		; branch if clear
	MOVWF	SCRATCH
	BTFSS	SCRATCH, bit
	GOTO	dest
	ENDM



;#############################################################################
;	Bit test W and CALL
;#############################################################################

BTWCS	MACRO	bit, dest		; call if set
	MOVWF	SCRATCH
	BTFSC	SCRATCH, bit
	CALL	dest
	ENDM
	
BTWCC	MACRO	bit, dest		; call if clear
	MOVWF	SCRATCH
	BTFSS	SCRATCH, bit
	CALL	dest
	ENDM



;#############################################################################
;	Bit test W and Skip
;#############################################################################

BTWSS	MACRO	bit			; skip if set
	MOVWF	SCRATCH
	BTFSS	SCRATCH, bit
	ENDM
	
BTWSC	MACRO	bit			; skip if clear
	MOVWF	SCRATCH
	BTFSC	SCRATCH, bit
	ENDM



;#############################################################################
;	Branch if W is true/false
;#############################################################################

BW_True		MACRO	dest
	ANDLW	0xFF
	BTFSC	STATUS, Z
	GOTO	dest
	ENDM
	
BW_False	MACRO	dest
	ANDLW	0xFF
	BTFSS	STATUS, Z
	GOTO	dest
	ENDM



;#############################################################################
;	Call if W is true/false
;#############################################################################

CW_True		MACRO	dest
	ANDLW	0xFF
	BTFSC	STATUS, Z
	CALL	dest
	ENDM
	
CW_False	MACRO	dest
	ANDLW	0xFF
	BTFSS	STATUS, Z
	CALL	dest
	ENDM



;#############################################################################
;	Skip if W is true/false
;#############################################################################

SW_True		MACRO
	ANDLW	0xFF
	BTFSS	STATUS, Z
	ENDM
	
SW_False	MACRO
	ANDLW	0xFF
	BTFSC	STATUS, Z
	ENDM



;#############################################################################
;	Instructions
;#############################################################################

; Store literal to file
STR	MACRO	lit, to			
	MOVLW	lit
	MOVWF	to
	ENDM

; Move file data to another file
MOV	MACRO	from, to
	MOVF	from, W
	MOVWF	to
	ENDM

; Negate (two's complement)
NEG	MACRO 	file
	COMF	file, F
	INCF	file, F
	ENDM
	
NEGw	MACRO
	XORLW	0xFF
	ADDLW	0x01
	ENDM
	
READp 	MACRO	address, file
	MOVF	address, W
	MOVWF	FSR
	MOVF	INDF, W
	MOVWF	file
	ENDM

WRITEp	MACRO	file, address
	MOVF	address, W
	MOVWF	FSR
	MOVF	file, W
	MOVWF	INDF
	ENDM

; SWAP content of 2 files
; not the nibbles like SWAPF
; can be used to swap bytes in short, or shorts in integer
SWAP	MACRO	a, b
	MOVF	a, W		; w = a
	MOVWF	SCRATCH		; s = a
	MOVF	b, W		; w = b
	MOVWF	a		; a = b
	MOVF	SCRATCH, W	; w = a
	MOVWF	b		; b = a
	ENDM
	
; Add 2 files
ADD	MACRO	a, b	; a = a + b
	MOVF	b, W
	ADDWF	a, F
	ENDM

; Sub 2 files (sub other file from target)
SUB	MACRO	a, b	; a = a - b
	MOVF	b, W
	SUBWF	a, F
	ENDM
	
; Add Literal
ADDL	MACRO	a, lit	; a = a + lit
	MOVLW	lit
	ADDWF 	a, F
	ENDM

; Subtract Literal
SUBL	MACRO	a, lit	; a = a - lit
	MOVLW	lit
	SUBWF	a, F
	ENDM
	
; Subtract a from b: subtract target from other file
SUBF	MACRO	a, b	; a = b - a
	MOVF	a, W
	SUBWF	b, W
	MOVWF	a
	ENDM

; Subtract From Literal
SUBFL	MACRO	a, lit	; a = lit - a
	MOVF	a, W
	SUBLW	lit
	MOVWF	a	
	ENDM



;#############################################################################
;	Read Timer1 data
;#############################################################################

READ_TMR1	MACRO dest
	LOCAL	_end
	MOVF	TMR1H, W ; Read high byte
	MOVWF	dest + 1
	MOVF	TMR1L, W ; Read low byte
	MOVWF	dest
	MOVF	TMR1H, W ; Read high byte
	SUBWF	dest + 1, W ; Sub 1st read with 2nd read
	BTFSC	STATUS, Z ; Is result = 0
	GOTO	_end
	; TMR1L may have rolled over between the read of the high and low bytes.
	; Reading the high and low bytes now will read a good value.
	MOVF	TMR1H, W ; Read high byte again
	MOVWF	dest + 1
	MOVF	TMR1L, W ; Read low byte
	MOVWF	dest ; Re-enable the Interrupt (if required)
_end:
	ENDM



;#############################################################################
;	ISR Context Push and Pop
;#############################################################################

; GPR files in shared GPR
STACK_W		EQU	0x7F
STACK_STATUS	EQU	0x7E
STACK_PCLATH	EQU	0x7D
SCRATCH		EQU	0x7C
STACK_SCRATCH	EQU	0x7B
STACK_FSR	EQU	0x7A


; Push and Pop for W, STATUS and PCLATH
; should be first to push and last to pop
;
;ex
; 	ORG 0x0000
; ISR:
; 	PUSH
; 	PUSHfsr
; 	PUSHscr
;
; ...isr...
;
; 	POPscr
; 	POPfsr
; 	POP
; 	REFTIE
;
; 	ORG 0x0004

PUSH	MACRO
	MOVWF	STACK_W
	SWAPF	STATUS, W
	MOVWF	STACK_STATUS
	CLRF	STATUS
	MOVF 	PCLATH, W
	MOVWF	STACK_PCLATH
	ENDM

POP	MACRO
	MOVF	STACK_PCLATH, W
	MOVWF 	PCLATH
	SWAPF	STACK_STATUS, W
	MOVWF	STATUS
	SWAPF	STACK_W, F
	SWAPF	STACK_W, W
	ENDM

; FSR
; required if ISR uses FSR
PUSHfsr	MACRO
	MOVF	FSR, W
	MOVWF	STACK_FSR
	ENDM
	
POPfsr	MACRO
	MOVF	STACK_FSR, W
	MOVWF	FSR
	ENDM
	
; Scratch register for expanded instructions
; required if ISR uses expanded instructions
PUSHscr	MACRO
	MOVF	SCRATCH, W
	MOVWF	STACK_SCRATCH
	ENDM
	
POPscr	MACRO
	MOVF	STACK_SCRATCH, W
	MOVWF	SCRATCH
	ENDM



;#############################################################################
;	Assertion functions to Test and Debug
;#############################################################################

#DEFINE STALL		GOTO	$
#DEFINE TRUE	0x00
#DEFINE FALSE	0x01

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
;	PC MSB Boundary skip
;#############################################################################

PC0x800SKIP	MACRO
	BSF	PCLATH, 3
	GOTO	_NEXT_BOUNDARY
	ORG	0x0800
_NEXT_BOUNDARY:
	ENDM
