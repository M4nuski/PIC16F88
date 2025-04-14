;#############################################################################
;	PIC16F88 Timing macro
;
;	For 8MHz oscillator
;	2MIPS
;	0.5us per instruction cycle
;	Uses RAM file WAIT_loopCounter1, WAIT_loopCounter2
;
;#############################################################################


inline_WAIT_50us MACRO	; 100i total,  setup and exit is 4i, then 7i, 10i, 13i for each counter values
	MOVLW	32			; (1)
	MOVWF	WAIT_loopCounter1	; (1)
	DECFSZ	WAIT_loopCounter1, F	; (1)
	GOTO	$ - 1			; (2/1)
	ENDM

inline_WAIT_5us	MACRO
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	ENDM
	
inline_WAIT_2us	MACRO
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	ENDM
	
inline_WAIT_1us	MACRO
	GOTO	$ + 1			; (2)
	ENDM


; sub_WAIT_50us: ; 7i overhead
	; NOP
	; MOVLW	31			; (1) 100 instruction for 50 us; 31*3 = 93, +7 = 100 instructions
	; MOVWF	WAIT_loopCounter1	; (1) (2) 4, 7, 10, 13 ... 1 + 3*l
	; DECFSZ	WAIT_loopCounter1, F	; (1)
	; GOTO	$ - 1			; (2/1)
	; RETURN

; sub_WAIT_5us: ;4i overhead
	; GOTO	$ + 1			; (2)
	; GOTO	$ + 1			; (2)
	; GOTO	$ + 1			; (2)
	; RETURN

; sub_WAIT_2us: ;4i overhead
	; RETURN



; ; total 100006 cycles / 50.003 ms
; sub_WAIT_50ms: ;4 i overhead
	; MOVLW	100			; (1)
	; MOVWF	WAIT_loopCounter1	; (1)
; ;4
; sub_WAIT_50ms_loop1:			; 
	; MOVLW	199			; (1)
	; MOVWF	WAIT_loopCounter2	; (1)
; ;2 * 100 = 200
; sub_WAIT_50ms_loop2:			; 5 cycles per loop
	; GOTO $ + 1			; (2)
	; DECFSZ	WAIT_loopCounter2, F	; (1)
	; GOTO	sub_WAIT_50ms_loop2	; (2)
; ;5 * 199 * 100 = 99500
	; DECFSZ	WAIT_loopCounter1, F	; (1)
	; GOTO	sub_WAIT_50ms_loop1	; (2)
; ;3 * 100 = 300
	; RETURN				; (2)
; ;2


