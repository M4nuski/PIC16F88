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
	
; b byte 8bit
; s short 16bit
; c color 24bit
; i int  32bit
; d double 64bit

; f file
; l literal
; w w register
; u unsigned
; s signed

; SCRATCH		EQU 0x7A
; STACK_SCRATCH	EQU 0x7B

; 8 bit compare
COMP_l_f	MACRO lit, file	; literal vs file
	MOVF	file, W			; w = f
	SUBLW	lit			; w = l - f(w)
	ENDM
	
COMP_f_f	MACRO file1, file2	; file1 vs file2
	MOVF	file2, W		; w = f2
	SUBWF	file1, W		; w = f1 - f2(w)
	ENDM

COMP_f_w	MACRO file		; file vs w
	SUBWF	file, W			; w = f - w
	ENDM

COMP_l_w	MACRO lit		; literal vs w
	SUBLW	lit			; w = l - w
	ENDM
	
; 8 bit branch
BR_EQ	MACRO	dest
	BTFSC	STATUS, Z
	GOTO	dest
	ENDM
	
BR_NE	MACRO	dest
	BTFSS	STATUS, Z
	GOTO	dest
	ENDM

BR_GT	MACRO 	dest
	BTFSC	STATUS, C
	GOTO	dest
	ENDM

BR_GE	MACRO 	dest
	BTFSC	STATUS, C
	GOTO	dest
	BTFSC	STATUS, Z
	GOTO	dest
	ENDM
	
BR_LT	MACRO	dest
	BTFSS	STATUS, C
	GOTO	dest
	ENDM

BR_LE	MACRO 	dest
	BTFSS	STATUS, C
	GOTO	dest
	BTFSC	STATUS, Z
	GOTO	dest
	ENDM

TEST_f	MACRO	file	; test file
	MOVF	file, F
	ENDM
	
TEST_w	MACRO		; test w
	ANDLW	0xFF
	ENDM
	
BR_ZE	MACRO	dest	; zero
	BTFSC	STATUS, Z
	GOTO	dest
	ENDM
SK_ZE	MACRO
	BTFSS	STATUS, Z
	ENDM
	
BR_NZ	MACRO	dest	; not zero
	BTFSS	STATUS, Z
	GOTO	dest
	ENDM
SK_NZ	MACRO
	BTFSC	STATUS, Z
	ENDM

BR_CA	MACRO	dest	; carry
	BTFSC	STATUS, C
	GOTO	dest
	ENDM
SK_CA	MACRO
	BTFSS	STATUS, C
	ENDM
	
BR_NC	MACRO	dest	; no carry
	BTFSS	STATUS, C
	GOTO	dest
	ENDM
SK_NC	MACRO
	BTFSC	STATUS, C
	ENDM
	
BR_BO	MACRO	dest	; borrow
	BTFSS	STATUS, C
	GOTO	dest
	ENDM
SK_BO	MACRO
	BTFSC	STATUS, C
	ENDM
	
BR_NB	MACRO	dest	; no borrow
	BTFSC	STATUS, C
	GOTO	dest
	ENDM
SK_NB	MACRO
	BTFSS	STATUS, C
	ENDM

BTFBS	MACRO	file, bit, dest	; bit test file, brach if set
	BTFSC	file, bit
	GOTO	dest
	ENDM
	
BTFBC	MACRO	file, bit, dest	; bit test file, branch if clear
	BTFSS	file, bit
	GOTO	dest
	ENDM

BTWBS	MACRO	bit, dest		; bit test w, branch if set
	MOVWF	SCRATCH
	BTFSC	SCRATCH, bit
	GOTO	dest
	ENDM
	
BTWBC	MACRO	bit, dest		; bit test w, branch if clear
	MOVWF	SCRATCH
	BTFSS	SCRATCH, bit
	GOTO	dest
	ENDM
	
	
	
MOV	MACRO	from, to
	MOVF	from, W
	MOVWF	to

MOVs 	MACRO	from, to
	MOVF	from, W
	MOVWF	to
	MOVF	from + 1, W
	MOVWF	to + 1
	ENDM
	
MOVc 	MACRO from, to
	MOVF	from, W
	MOVWF	to
	MOVF	from + 1, W
	MOVWF	to + 1
	MOVF	from + 2, W
	MOVWF	to + 2
	ENDM
	
MOVi 	MACRO	from, to
	MOVF	from, W
	MOVWF	to
	MOVF	from + 1, W
	MOVWF	to + 1
	MOVF	from + 2, W
	MOVWF	to + 2
	MOVF	from + 3, W
	MOVWF	to + 3
	ENDM

ADD	MACRO	a, b	; a = a + b
	MOVF	b, W
	ADDWF	a, F
	ENDM

SUB	MACRO	a, b	; a = a - b
	MOVF	b, W
	SUBWF	a, F
	ENDM
	
ADDs	MACRO	a, b	; a = a + b
	MOVF	b, W
	ADDWF 	a, F
	SK_NC
	INCF	a + 1, F
	MOVF	b + 1, W
	ADDWF	a + 1, F
	ENDM

SUBs	MACRO	a, b	; a = a - b
	MOVF	b, W
	SUBWF	a, F
	SK_NB
	DECF	a + 1, F
	MOVF	b + 1, W
	SUBWF	a + 1, F
	ENDM

ADDc	MACRO	a, b	; a = a + b
	MOVF	b, W
	ADDWF 	a, F
	SK_NC
	INCF	a + 1, F
	SK_NC
	INCF	a + 2, F
	MOVF	b + 1, W
	ADDWF	a + 1, F
	SK_NC
	INCF	a + 2, F
	MOVF	b + 2, W
	ADDWF	a + 2, F	
	ENDM
	
SUBc	MACRO	a, b	; a = a - b
	MOVF	b, W
	SUBWF	a, F
	SK_NB
	DECF	a + 1, F
	SK_NB
	DECF	a + 2, F
	MOVF	b + 1, W
	SUBWF	a + 1, F
	SK_NB
	DECF	a + 2, F
	MOVF	b + 2, W
	SUBWF	a + 2, F
	ENDM
	
ADDi	MACRO	a, b	; a = a + b
	MOVF	b, W
	ADDWF 	a, F
	SK_NC
	INCF	a + 1, F
	SK_NC
	INCF	a + 2, F
	SK_NC
	INCF	a + 3, F
	MOVF	b + 1, W
	ADDWF	a + 1, F
	SK_NC
	INCF	a + 2, F
	SK_NC
	INCF	a + 3, F
	MOVF	b + 2, W
	ADDWF	a + 2, F
	SK_NC	
	INCF	a + 3, F
	MOVF	b + 3, W
	ADDWF	a + 3, F
	ENDM
	
SUBi	MACRO	a, b	; a = a - b
	MOVF	b, W
	SUBWF	a, F
	SK_NB
	DECF	a + 1, F
	SK_NB
	DECF	a + 2, F
	SK_NB
	DECF	a + 3, F
	MOVF	b + 1, W
	SUBWF	a + 1, F
	SK_NB
	DECF	a + 2, F
	SK_NB
	DECF	a + 3, F
	MOVF	b + 2, W
	SUBWF	a + 2, F
	SK_NB
	DECF	a + 3, F
	MOVF	b + 3, W
	SUBWF	a + 3, F
	ENDM
	
BR_W_LT_W	MACRO word1, word2, dest	;branch to dest if word1 < word2 
	LOCAL BRWLTW1
	LOCAL BRWLTW2
	; test high byte
	MOVF word2 + 1, W ; W = word2
	SUBWF word1 + 1, W ; Subtract W(word2) from f(word1)
	; w = word1 - word2
	; if equal Z is set, C is set (borrow is clear)
	; if word1 > word2 C is set (borrow is clear)
	; if word1 < word2 C is clear (borrow is set)
	
	BTFSS STATUS, C; skip if C is set (borrow is clear, word1 >= word2)
	GOTO dest; high byte is less
	
	BTFSC STATUS, Z; check if equal
	GOTO BRWLTW1; if high bytes are equal test low bytes
	GOTO BRWLTW2; otherwise word1 > word2
	; test low byte
BRWLTW1:
	MOVF word2, W
	SUBWF word1, W	
	BTFSS STATUS, C
	GOTO dest
BRWLTW2:
	ENDM
	
BR_W_GT_W	MACRO word1, word2, dest	;branch to dest if word1 > word2 
	LOCAL BRWGTW1
	LOCAL BRWGTW2
	; test high byte
	MOVF word1 + 1, W ; W = word1
	SUBWF word2 + 1, W ; Subtract W(word1) from f(word2)
	; w = word2 - word1
	BTFSS STATUS, C; skip if C is set 
	GOTO dest; high byte is less	
	BTFSC STATUS, Z; check if equal
	GOTO BRWGTW1;
	GOTO BRWGTW2;
BRWGTW1:
	MOVF word1, W
	SUBWF word2, W	
	BTFSS STATUS, C
	GOTO dest
BRWGTW2:
	ENDM

	
BR_W_EQ_W	MACRO word1, word2, dest	;branch to dest if word1 == word2
	LOCAL BRWWEQW
	; test high byte
	MOVF word1 + 1, W
	SUBWF word2 + 1, W
	BTFSS STATUS, Z
	GOTO BRWWEQW
	; test low byte
	MOVF word1, W
	SUBWF word2, W
	BTFSC STATUS, Z
	GOTO dest
BRWWEQW:
	ENDM	

;C: Carry/borrow bit (ADDWF, ADDLW, SUBLW and SUBWF instructions)(1,2)
;1 = A carry-out from the Most Significant bit of the result occurred
;0 = No carry-out from the Most Significant bit of the result occurred

READ_TMR0	MACRO destH, destL
	LOCAL CONTINUE_READ_TMR0
	MOVF TMR1H, W ; Read high byte
	MOVWF destH
	MOVF TMR1L, W ; Read low byte
	MOVWF destL
	MOVF TMR1H, W ; Read high byte
	SUBWF destH, W ; Sub 1st read with 2nd read
	BTFSC STATUS, Z ; Is result = 0
	GOTO CONTINUE_READ_TMR0 ; Good 16-bit read
	; TMR1L may have rolled over between the read of the high and low bytes.
	; Reading the high and low bytes now will read a good value.
	MOVF TMR1H, W ; Read high byte
	MOVWF destH
	MOVF TMR1L, W ; Read low byte
	MOVWF destL ; Re-enable the Interrupt (if required)
CONTINUE_READ_TMR0:  ; Continue with your code
	ENDM
	
PUSH	MACRO
	MOVWF	STACK_W
	SWAPF	STATUS, W
	CLRF	STATUS
	MOVWF	STACK_STATUS
	MOVF	PCLATH, W
	MOVWF	STACK_PCLATH
	CLRF	PCLATH
	MOVF	FSR, W
	MOVWF	STACK_FSR
	ENDM

POP	MACRO
	MOVF	STACK_FSR, W
	MOVWF	FSR
	MOVF	STACK_PCLATH, W
	MOVWF 	PCLATH
	SWAPF	STACK_STATUS, W
	MOVWF	STATUS
	SWAPF	STACK_W, F
	SWAPF	STACK_W, W
	ENDM
	
PUSHq	MACRO
	MOVWF	STACK_W
	SWAPF	STATUS, W
	CLRF	STATUS
	MOVWF	STACK_STATUS
	ENDM

POPq	MACRO
	SWAPF	STACK_STATUS, W
	MOVWF	STATUS
	SWAPF	STACK_W, F
	SWAPF	STACK_W, W
	ENDM