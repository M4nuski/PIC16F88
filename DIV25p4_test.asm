;#############################################################################
;
;	mm div by 25.4 test
;	blocking sync UART with CTS flow control
; test4 is is giving correct results, but takes very long and much memory
; test6 is perfect progressive approx
;
;#############################################################################

	LIST	p=16F88			; processor model
#INCLUDE	<P16F88.INC>		; processor specific variable definitions
#INCLUDE	<PIC16F88_Macro.asm>	; base macro for banks, context, branchs
#INCLUDE	<PIC16F88_MacroExt.asm> ; 16/24/32 bit instructions extensions
	ERRORLEVEL -302		; suppress "bank" warnings

;#############################################################################
;	Configuration
;#############################################################################

	__CONFIG	_CONFIG1, 	_CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & _WDT_OFF & _INTRC_IO
	__CONFIG	_CONFIG2, 	_IESO_OFF & _FCMEN_OFF

;#############################################################################
;	Pinout
;#############################################################################

; PIC16F88:
; pin  1 IOA PORTA2	
; pin  2 IOA PORTA3	
; pin  3 IOA PORTA4	
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	
; pin  7 IO_ PORTB1	
; pin  8 IOR PORTB2	I UART RX
; pin  9 IO_ PORTB3	

; pin 10 IO_ PORTB4	
; pin 11 IOT PORTB5	O UART TX
; pin 12 IOA PORTB6	
; pin 13 IOA PORTB7	
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O ISR Status Bit
; pin 16 I_X PORTA7	
; pin 17 IOA PORTA0	
; pin 18 IOA PORTA1	


#DEFINE pin_CTS	PORTA, 0
;#DEFINE 		PORTA, 1
;#DEFINE 		PORTA, 2
;#DEFINE 		PORTA, 3
;#DEFINE 		PORTA, 4
;#DEFINE	MCLR		PORTA, 5
#DEFINE pin_ISR		PORTA, 6
;#DEFINE  		PORTA, 7

;#DEFINE 		PORTB, 0
;#DEFINE 		PORTB, 1
#DEFINE UART_RX		PORTB, 2
;#DEFINE 		PORTB, 3
;#DEFINE 		PORTB, 4
#DEFINE UART_TX		PORTB, 5
;#DEFINE 	PGC		PORTB, 6
;#DEFINE 	PGD		PORTB, 7

;#############################################################################
;	Memory Organisation
;#############################################################################

; Bank #    SFR           GPR               SHARED GPR's			total 368 bytes of GPR, 16 shared between banks
; Bank 0    0x00-0x1F     0x20-0x7F         target area 0x70-0x7F		96
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  			80 + 16 shared with bank 0
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F			16 + 80 + 16 shared with bank 0
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF			16 + 80 + 16 shared with bank 0

;#############################################################################
;	File Variables and Constants
;#############################################################################
; Bank 0

count_01ms		EQU	0x20
count_25ms		EQU	0x21
count_1s		EQU	0x22
div_loop		EQU	0x23

serial_data		EQU	0x2F
buffer0			EQU	0x30

test_index		EQU	0x3D
inst_count_0		EQU	0x3E
inst_count_1		EQU	0x3F

data_f			EQU	0x40
data_0			EQU	0x41
data_1			EQU	0x42
data_2			EQU	0x43

accum_0			EQU	0x44
accum_1			EQU	0x45
accum_2			EQU	0x46



temp_0			EQU	0x25
temp_1			EQU	0x26
temp_2			EQU	0x27

index_0			EQU	0x32
index_1			EQU	0x33
index_2			EQU	0x34

divisor_0		EQU	0x48
divisor_1		EQU	0x49
divisor_2		EQU	0x4A


accum_flags		EQU	0x50

;#############################################################################
;	Reset Vector - Main Entry Point
;#############################################################################

	ORG	0x0000
	GOTO	SETUP

;#############################################################################
;	Interrupt Vector - Interrupt Service Routine
;#############################################################################

	ORG	0x0004
ISR:
	BSF	pin_ISR
	STALL	; ISR trap, this code should not be reachable
	RETFIE

;#############################################################################
;	Initial Setup
;#############################################################################

SETUP:
	BANK1
	; init analog inputs
	CLRF	ANSEL		; all digital
	
	; init port directions 
	CLRF	TRISA		; all outputs
	
	CLRF	TRISB		; all outputs
	BSF	UART_RX		; input
	
	; init osc 8MHz
	BCF	OSCCON, SCS0
	BCF	OSCCON, SCS1
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
SETUP_OSC:
	BTFSS	OSCCON, IOFS
	GOTO	SETUP_OSC
	
	;BSF	TXSTA, CSRC	; not used in async - set as clock source master
	BCF 	TXSTA, TX9	; 8 bit tx
	BSF	TXSTA, TXEN	; enable tx
	BCF	TXSTA, SYNC	; async
	
	; set 9600 baud rate
	BSF 	TXSTA, BRGH	; high speed baud rate generator	
	MOVLW	51		; 9600 bauds
	MOVWF	SPBRG
	
	BANK0
	
	BSF	RCSTA, SPEN	; serial port enabled
	BCF	RCSTA, RX9	; 8 bit rx
	BSF	RCSTA, CREN	; enable continuous receive
	BCF	RCSTA, ADDEN	; disable addressing
	
	; ports
	CLRF	PORTA
	CLRF	PORTB	
	
	; timer1 as instruction counter

	BCF	T1CON, T1CKPS0	; 0
	BCF	T1CON, T1CKPS1	; 0
	BCF	T1CON, TMR1CS	; timer1 clock is FOSC/4
	


main:
;welcome message
	BSF	pin_CTS

	BSF	PORTA, 2 
	CALL	WAIT_1s	
	BSF	PORTA, 3
	
	MOVLW	'D'
	MOVWF	serial_data
	CALL 	SEND_BYTE	
	MOVLW	'I'
	MOVWF	serial_data
	CALL 	SEND_BYTE
	MOVLW	'V'
	MOVWF	serial_data
	CALL 	SEND_BYTE
	
	MOVLW	'2'
	MOVWF	serial_data
	CALL 	SEND_BYTE	
	MOVLW	'5'
	MOVWF	serial_data
	CALL 	SEND_BYTE	
	MOVLW	'.'
	MOVWF	serial_data
	CALL 	SEND_BYTE	
	MOVLW	'4'
	MOVWF	serial_data
	CALL 	SEND_BYTE
	
	MOVLW	13	;(CR)
	MOVWF	serial_data
	CALL 	SEND_BYTE	
	MOVWF	serial_data
	MOVLW	10	;(LF)
	CALL 	SEND_BYTE

	BSF	PORTA, 4
	
	; 998 = 0x03E6 = b'0000001111100110'
	; 999 = 0x03E7 = b'0000001111100111'
	;1000 = 0x03E8 = b'0000001111101000'
	;1001 = 0x03E9 = b'0000001111101001'	
	;25400 = 0x6338 = b'0110001100111000'
	
	STRc	0x006338, data_0
	STR	6, test_index

loop:
	CLRF	TMR1L
	CLRF	TMR1H
	MOVLW	-5
	MOVWF	inst_count_0	
	CLRF	inst_count_1
	CLRFc	accum_0

loop_t0:
	CMP_lf	0, test_index
	BR_NE	loop_t1
	MOVLW	HIGH( test0 )
	MOVWF	PCLATH
	SUBWF	inst_count_1, F
	CALL	test0
	GOTO	loop_end
	
loop_t1:
	CMP_lf	1, test_index
	BR_NE	loop_t2
	MOVLW	HIGH( test1 )
	MOVWF	PCLATH
	SUBWF	inst_count_1, F
	CALL	test1
	GOTO	loop_end
	
loop_t2:
	CMP_lf	2, test_index
	BR_NE	loop_t3
	MOVLW	HIGH( test2 )
	MOVWF	PCLATH
	SUBWF	inst_count_1, F
	CALL	test2
	GOTO	loop_end
	
loop_t3:
	CMP_lf	3, test_index
	BR_NE	loop_t4
	MOVLW	HIGH( test3 )
	MOVWF	PCLATH
	SUBWF	inst_count_1, F
	CALL	test3
	GOTO	loop_end
	
loop_t4:
	CMP_lf	4, test_index
	BR_NE	loop_t5
	MOVLW	HIGH( test4 )
	MOVWF	PCLATH
	SUBWF	inst_count_1, F
	CALL	test4
	GOTO	loop_end

loop_t5:
	CMP_lf	5, test_index
	BR_NE	loop_t6
	MOVLW	HIGH ( test5 )
	MOVWF	PCLATH
	SUBWF	inst_count_1, F
	CALL	test5
	GOTO	loop_end
	
loop_t6:
	CMP_lf	6, test_index
	BR_NE	loop_end
	MOVLW	HIGH ( test6 )
	MOVWF	PCLATH
	SUBWF	inst_count_1, F
	CALL	test6
	GOTO	loop_end
	
loop_end:
	BTFSS	PIR1, TMR1IF
	GOTO	div_noOverflow
	MOVLW	'X'
	MOVWF	serial_data
	CALL 	SEND_BYTE
		
div_noOverflow:
	MOVLW	HIGH( table_nibbleHex )
	MOVWF	PCLATH	
	
	; time
	MOVLW	' '
	MOVWF	serial_data
	CALL 	SEND_BYTE 
	MOVLW	't'
	MOVWF	serial_data
	CALL 	SEND_BYTE 
	
	MOVLW	TMR1H
	MOVWF	FSR
	CALL	SEND2HEX
	
	; instructions
	MOVLW	' '
	MOVWF	serial_data
	CALL 	SEND_BYTE	
	MOVLW	'i'
	MOVWF	serial_data
	CALL 	SEND_BYTE
	
	MOVLW	inst_count_1
	MOVWF	FSR
	CALL	SEND2HEX
	
	; result	
	MOVLW	' '
	MOVWF	serial_data
	CALL 	SEND_BYTE	
	MOVLW	'r'
	MOVWF	serial_data
	CALL 	SEND_BYTE
	
	MOVLW	accum_2
	MOVWF	FSR
	CALL	SEND3HEX
	
	CALL	WAIT_BYTE
	MOV	serial_data, test_index
	
	CALL	WAIT_BYTE
	MOV	serial_data, data_2
	
	CALL	WAIT_BYTE
	MOV	serial_data, data_1
	
	CALL	WAIT_BYTE
	MOV	serial_data, data_0	
	
	MOVLW	0x04
	XORWF	PORTA, F

	GOTO	loop

; send hex data, MSB first, FSR point to LAST BYTE
SEND4HEX:
	SWAPF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	MOVWF	serial_data
	CALL 	SEND_BYTE
	
	MOVF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	MOVWF	serial_data
	CALL 	SEND_BYTE	
	
	DECF	FSR, F
SEND3HEX:
	SWAPF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	MOVWF	serial_data
	CALL 	SEND_BYTE
	
	MOVF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	MOVWF	serial_data
	CALL 	SEND_BYTE	
	
	DECF	FSR, F
SEND2HEX:
	SWAPF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	MOVWF	serial_data
	CALL 	SEND_BYTE
	
	MOVF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	MOVWF	serial_data
	CALL 	SEND_BYTE	
	
	DECF	FSR, F
SEND1HEX:
	SWAPF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	MOVWF	serial_data
	CALL 	SEND_BYTE
	
	MOVF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	MOVWF	serial_data
	CALL 	SEND_BYTE	
	
	RETURN

;#############################################################################
;	Tables
;#############################################################################

	PC0x0100SKIP; align to next 256 byte boundary in program memory
	
; nibble to char
table_nibbleHex:
	ADDWF	PCL, F
	dt	"0123456789ABCDEF"
	
SEND_BYTE:
	BTFSS	PIR1, TXIF
	GOTO	SEND_BYTE
	MOVF	serial_data, W
	MOVWF	TXREG
	RETURN
	
WAIT_BYTE:
	BCF	pin_CTS
	BTFSS	PIR1, RCIF
	GOTO	WAIT_BYTE
	BSF	pin_CTS
	MOVF	RCREG, W
	MOVWF	serial_data
	RETURN



WAIT_1s:
	MOVLW	40
	MOVWF	count_1s
WAIT_1s_loop:
	NOP
	CALL	WAIT_25ms
	DECFSZ	count_1s, F
	GOTO	WAIT_1s_loop
	RETURN

WAIT_25ms:				; call 2 cycles
	MOVLW	250			; for 25 ms
	MOVWF	count_25ms		
WAIT_25ms_loop:
	NOP
	CALL	WAIT_01ms
	DECFSZ	count_25ms, F
	GOTO	WAIT_25ms_loop
	RETURN

WAIT_01ms:				; call 2 cycle
	MOVLW	50 - 2			; 50 loops of 4 cycles (minus setup and return) 
	MOVWF	count_01ms		; 1
	NOP				; 1 
	NOP				; 1
	; call and return 8 cycles
WAIT_01ms_loop:			;	4 per loop
	NOP				; 1
	DECFSZ	count_01ms, F		; 1
	GOTO	WAIT_01ms_loop		; 2
	RETURN				; return 2 cycles
	
	
	
	
test0:
	PC0x0100SKIP
	BSF	T1CON, TMR1ON	; timer1 ON
;****	TEST 0 START ****
	NOP
;*****	TEST 0 STOP **** 
	BCF	T1CON, TMR1ON	; timer1 OFF	
	MOVF	PCLATH, W
	ADDWF	inst_count_1, F
	MOVF	PCL, W
	ADDWF	inst_count_0, F
	
	MOVLW	HIGH (loop)
	MOVWF	PCLATH
	RETURN
	
test1:
	PC0x0100SKIP
	BSF	T1CON, TMR1ON	; timer1 ON

	; /32	+/128	+/4096	
	
	; loopy unoptimized version
	;t00A6 i0076 r00271E 	 10014 instead of 10000
	
;*****	TEST 1 START **** 

	STR	5, div_loop	;5
t1_32:
	BCF	STATUS, C
	RRFc	data_0
	
	DECFSZ	div_loop, F
	GOTO	t1_32
	
	MOVc	data_0, accum_0


	STR	2, div_loop ;7 = 2 + 5
t1_128:
	BCF	STATUS, C
	RRFc	data_0
	
	DECFSZ	div_loop, F
	GOTO	t1_128
	
	ADDc	accum_0, data_0
	
	
	STR	5, div_loop ;12 = 5 + 7
t1_4096:
	BCF	STATUS, C
	RRFc	data_0
	
	DECFSZ	div_loop, F
	GOTO	t1_4096	
	
	ADDc	accum_0, data_0
	
;8192
	BCF	STATUS, C
	RRFc	data_0
	ADDc	accum_0, data_0
	
;*****	TEST 1 STOP **** 
	BCF	T1CON, TMR1ON	; timer1 OFF	
	MOVF	PCLATH, W
	ADDWF	inst_count_1, F
	MOVF	PCL, W
	ADDWF	inst_count_0, F
	
	MOVLW	HIGH (loop)
	MOVWF	PCLATH
	RETURN
	
test2:
	PC0x0100SKIP
	BSF	T1CON, TMR1ON	; timer1 ON
	; /32	+/128	+/4096	+/16384 
	; 5     7       12     14     
	;

	; loopy unoptimized version
	;t00A6 i0076 r00271E 	 10014 instead of 10000
	
;*****	TEST 2 START **** 
	BCF	accum_flags, 0
	
	STR	5, div_loop	;5
t2_32:
	BCF	STATUS, C
	RRFc	data_0
	BTFSC	STATUS, C
	BSF	accum_flags, 0
	DECFSZ	div_loop, F
	GOTO	t2_32
	
	BTFSS	accum_flags, 0
	GOTO	t2_32_post
	INCFc	data_0
	BCF	accum_flags, 0
	
t2_32_post:
	MOVc	data_0, accum_0
	

	STR	2, div_loop ;7 = 2 + 5
t2_128:
	BCF	STATUS, C
	RRFc	data_0
	BTFSC	STATUS, C
	BSF	accum_flags, 0
	DECFSZ	div_loop, F
	GOTO	t2_128
	
	BTFSS	accum_flags, 0
	GOTO	t2_128_post
	INCFc	data_0
	BCF	accum_flags, 0

t2_128_post:
	ADDc	accum_0, data_0
	
	
	STR	5, div_loop ;12 = 5 + 7
t2_4096:
	BCF	STATUS, C
	RRFc	data_0
	BTFSC	STATUS, C
	BSF	accum_flags, 0
	DECFSZ	div_loop, F
	GOTO	t2_4096	
	
	BTFSS	accum_flags, 0
	GOTO	t2_4096_post
	INCFc	data_0
	BCF	accum_flags, 0

t2_4096_post:
	ADDc	accum_0, data_0
	

	STR	2, div_loop ;14 = 2 + 12
t2_16384:
	BCF	STATUS, C
	RRFc	data_0
	BTFSC	STATUS, C
	BSF	accum_flags, 0
	DECFSZ	div_loop, F
	GOTO	t2_16384

	BTFSS	accum_flags, 0
	GOTO	t2_16384_post
	INCFc	data_0
	BCF	accum_flags, 0
	
t2_16384_post:
	ADDc	accum_0, data_0


;*****	TEST 2 STOP **** 
	BCF	T1CON, TMR1ON	; timer1 OFF	
	MOVF	PCLATH, W
	ADDWF	inst_count_1, F
	MOVF	PCL, W
	ADDWF	inst_count_0, F
	
	MOVLW	HIGH (loop)
	MOVWF	PCLATH
	RETURN
	
test3:
	PC0x0100SKIP
	BSF	T1CON, TMR1ON	; timer1 ON
	; /32	+/128	+/4096	+/16384 +/131072 
	; 5     7       12     14      17
	; if lsb in carry is 1 increase for round up at 0.5

	; loopy unoptimized version
	;t00A6 i0076 r00271E 	 10014 instead of 10000
	
;*****	TEST 3 START **** 

	CLRF	accum_flags

	STR	5, div_loop	;5
t3_32:
	BCF	STATUS, C
	RRFc	data_0
	BTFSC	STATUS, C
	BSF	accum_flags, 0
	DECFSZ	div_loop, F
	GOTO	t3_32	

	BTFSS	accum_flags, 0
	GOTO	t3_32_post
	;INCFc	data_0
	BCF	accum_flags, 0
t3_32_post:
	MOVc	data_0, accum_0

	STR	2, div_loop ;7 = 2 + 5
t3_128:
	BCF	STATUS, C
	RRFc	data_0
	BTFSC	STATUS, C
	BSF	accum_flags, 0
	DECFSZ	div_loop, F
	GOTO	t3_128	

	BTFSS	accum_flags, 0
	GOTO	t3_128_post
	;INCFc	data_0
	BCF	accum_flags, 0
t3_128_post:
	ADDc	accum_0, data_0

	STR	5, div_loop ;12 = 5 + 7
t3_4096:
	BCF	STATUS, C
	RRFc	data_0
	BTFSC	STATUS, C
	BSF	accum_flags, 0
	DECFSZ	div_loop, F
	GOTO	t3_4096	

	BTFSS	accum_flags, 0
	GOTO	t3_4096_post
	;INCFc	data_0
	BCF	accum_flags, 0
t3_4096_post:
	ADDc	accum_0, data_0
	
	STR	2, div_loop ;14 = 2 + 12
t3_16384:
	BCF	STATUS, C
	RRFc	data_0
	BTFSC	STATUS, C
	BSF	accum_flags, 0
	DECFSZ	div_loop, F
	GOTO	t3_16384	

	BTFSS	accum_flags, 0
	GOTO	t3_16384_post
	INCFc	data_0
	BCF	accum_flags, 0
t3_16384_post:
	ADDc	accum_0, data_0
	
	STR	3, div_loop ;17 = 3 + 14
t3_131072:
	BCF	STATUS, C
	RRFc	data_0
	BTFSC	STATUS, C
	BSF	accum_flags, 0
	DECFSZ	div_loop, F
	GOTO	t3_131072
	
	BTFSS	accum_flags, 0
	GOTO	t3_131072_post
	INCFc	data_0

t3_131072_post:
	ADDc	accum_0, data_0
	BTFSS	STATUS, C
	GOTO	t3_end
	INCFc	accum_0
t3_end:
	
;*****	TEST 3 STOP **** 
	BCF	T1CON, TMR1ON	; timer1 OFF	
	MOVF	PCLATH, W
	ADDWF	inst_count_1, F
	MOVF	PCL, W
	ADDWF	inst_count_0, F
	
	MOVLW	HIGH (loop)
	MOVWF	PCLATH
	RETURN
	
	
	
test4:
	PC0x0100SKIP
	BSF	T1CON, TMR1ON	; timer1 ON


; 148 inst, 773 cycles...
	BCF	STATUS, C
	RLFc	data_0 ;x2
	RLFc	data_0 ;x4
	MOVc	data_0, accum_0 ; accum is data * 4
			
	BCF	STATUS, C
	RLFc	data_0 ;x8
	RLFc	data_0 ;x16
	RLFc	data_0 ;x32		
	ADDc	accum_0, data_0; accum is data * 4 + data * 32
	
	BCF	STATUS, C
	RLFc	data_0 ;x64
	ADDc	data_0, accum_0; data is data * 4 + data * 32 + data * 64 == (100 * data)
		
		
	; data is max 0F FF FF
	; clamp down to 00 FF FF which is 655.36 mm or 25.8 inches
	; *100 = 64 00 00  000 0000  0110 0100  0000 0000  0000 0000
		
	; x100 / 127 = 1.27
	; post /127 div by 2 for 2.54
	; prepped to avoid pre shifting
	STR	254, divisor_2
	CLRF	divisor_1
	CLRF	divisor_0
	
	
	;DIV by 254
	;STR	254, divisor_0
	;CLRF	divisor_1
	;CLRF	divisor_2
	
;*****	TEST 4 START **** 

; accum = data / divisor
	CLRF	accum_0
	CLRF	accum_1
	CLRF	accum_2

	; prepped to avoid pre shifting
	MOVLW	0x02
	MOVWF	index_2
	CLRF	index_1
	CLRF	index_0

; divisor is know value that is not 0
	; MOVF	divisor_0, F	;CHECK IF CNT = 0
	; BTFSS	STATUS, Z
	; GOTO	DIVSTRT	
	; MOVF	divisor_1, F
	; BTFSS	STATUS, Z
	; GOTO	DIVSTRT
	; MOVF	divisor_2, F
	; BTFSC	STATUS, Z
	; GOTO	DIVEND

; DIVSTRT:
	; BTFSC	divisor_2, 7	;IF BIT 23 ALREADY AT 1 SKIP SHIFTING
	; GOTO	DIVLP
	
; DIVSHFT:
	; BCF	STATUS, C
	; RLF	divisor_0, F
	; RLF	divisor_1, F
	; RLF	divisor_2, F
	; BCF	STATUS, C
	; RLF	index_0, F
	; RLF	index_1, F
	; RLF	index_2, F
	; BTFSS	divisor_2, 7
	; GOTO	DIVSHFT
; divisor is known to be 0111 1111 and can be shifted staticaly
; index 0000 0000  0000 0000  0000 0001
; divis 0000 0000  0000 0000  0111 1111
; to:
; index 0000 0010  0000 0000  0000 0000 
; divis 1111 1110  0000 0000  0000 0000 

DIVLP:
	MOVF	data_0, W
	MOVWF	temp_0
	MOVF	data_1, W
	MOVWF	temp_1
	MOVF	data_2, W
	MOVWF	temp_2		;TEMP = data

	MOVF	divisor_0, W
	SUBWF	temp_0, F
	MOVF	divisor_1, W
	BTFSS	STATUS, C
	INCFSZ	divisor_1, W
	SUBWF	temp_1, F
	MOVF	divisor_2, W
	BTFSS	STATUS, C
	INCFSZ	divisor_2, W
	SUBWF	temp_2, F	;TEMP = TEMP - divisor	

	BTFSS	STATUS, C	; WHEN SUBTRACTING, THE CARRY IS INVERTED (BORROW)
	GOTO	DIVNXT		;IF NEGATIVE RESET AND CONTINUE
				;IF POSITIVE INCREMENT accum WITH index AND CONTINUE	
	MOVF	index_0, W
	ADDWF	accum_0, F
	MOVF	index_1, W
	BTFSC	STATUS, C
	INCFSZ	index_1, W
	ADDWF	accum_1, F
	MOVF	index_2, W
	BTFSC	STATUS, C
	INCFSZ	index_2, W
	ADDWF	accum_2, F	;accum := accum + index

	MOVF	temp_0, W
	MOVWF	data_0
	MOVF	temp_1, W
	MOVWF	data_1
	MOVF	temp_2, W
	MOVWF	data_2		;data := TEMP

DIVNXT:
	BCF	STATUS, C
	RRF	divisor_2, F
	RRF	divisor_1, F
	RRF	divisor_0, F
	BCF	STATUS, C
	RRF	index_2, F
	RRF	index_1, F
	RRF	index_0, F
	BTFSS	STATUS, C	;exit when index bit get out 
	GOTO	DIVLP
	
DIVEND:
	BTFSS	accum_0, 0 ; check for 0.5 end
	GOTO	t4_end	
	INCFc	accum_0	; inc to round up

t4_end:
	BCF	STATUS, C
	RRFc	accum_0	; div / 2

;*****	TEST 4 STOP **** 
	BCF	T1CON, TMR1ON	; timer1 OFF	
	MOVF	PCLATH, W
	ADDWF	inst_count_1, F
	MOVF	PCL, W
	ADDWF	inst_count_0, F
	
	MOVLW	HIGH (loop)
	MOVWF	PCLATH
	RETURN
	
test5:
	PC0x0800SKIP
	BSF	T1CON, TMR1ON	; timer1 ON

	; /2 + /4 + /32 + /128 - /512 + /4096 + /16k - /64k + /512k
		; +	+	+	-	+	+	-
	; target is 1/1.27:	0.787402	0.500000	0.250000	0.031250	0.007813	0.001953	
; div	bitshift		2	4	32	128	512	4096	16384	65536
	
;*****	TEST 5 START **** 
;	2	4	8	16	32	64	128	256
;	512	1024	2048	4096	8192	16k	32k	64k
;	128k	256k	512k	1024k	2048k	4096k	8192k	16m

;         no shift,	1byte,	2byte
; no bit shift  /1	/256	/64k
; after /2      /2	/512	/128k
; after /4      /4	/1024	/256k
; after /8      /8	/2k	/512k
; after /16	 /16	/4k	/1m
; after /32	 /32	/8k	/2m
; after /64	 /64	/16k	/4m
; after /128	/128	/32k	/8m

; after /256 	/256	/64k	/16m 

	;step 1 with base
	;			                       - /64k      
	; /2 + /4 + /32 + /128 - /512 + /4096 + /16k - /64k + /512k


	MOVF	data_2, W
	SUBWF	accum_0, F
	BR_NB	t5_0
	MOVLW	1
	SUBWF	accum_1, F	
	SK_NB
	DECF	accum_2, F
t5_0:
	; accum is now -/64k
	
	BCF	STATUS, C
	RRFc	data_0	;/2
	; +2			    -512                      
	; /2 + /4 + /32 + /128 - /512 + /4096 + /16k - /64k + /512k
	
	ADDc	accum_0, data_0 ;accum =  -/64k + /2
	;sub offset 1 for 512
	
	; offset sub
	MOVF	data_1, W
	SUBWF	accum_0, F
	BR_NB	t5_1
	MOVLW	1
	SUBWF	accum_1, F
	SK_NB
	DECF	accum_2, F
t5_1:
	MOVF	data_2, W
	SUBWF	accum_1, F
	SK_NB
	DECF	accum_2, F
	
	;accum =  -/64k + /2 - /512
	
	BCF	STATUS, C
	RRFc	data_0	;/4
	
	; 	/4		                       
	; /2 + /4 + /32 + /128 - /512 + /4096 + /16k - /64k + /512k
	
	ADDc	accum_0, data_0 ;accum =  -/64k + /2 - /512 + /4
	
	BCF	STATUS, C
	RRFc	data_0	;/8
	;							+ /512k
	; /2 + /4 + /32 + /128 - /512 + /4096 + /16k - /64k + /512k
	MOVF	data_2, W
	ADDWF	accum_0, F
	BR_NC	t5_2
	INCF	accum_1, F
	SK_NZ
	INCF	accum_2, F	 ;accum =  -/64k + /2 - /512 + /4 + 512k
t5_2:
	BCF	STATUS, C
	RRFc	data_0	;/16
	;				 + /4k			
	; /2 + /4 + /32 + /128 - /512 + /4096 + /16k - /64k + /512k
	
	MOVF	data_1, W
	ADDWF	accum_0, F
	BR_NC	t5_3
	INCF	accum_1, F
	SK_NZ
	INCF	accum_2, F
t5_3
	MOVF	data_2, W
	ADDWF	accum_1, F
	SK_NC
	INCF	accum_2, F  ;accum =  -/64k + /2 - /512 + /4 + /512k + /4k
	
	BCF	STATUS, C
	RRFc	data_0	;/32
	;	     +32					
	; /2 + /4 + /32 + /128 - /512 + /4096 + /16k - /64k + /512k
	ADDc	accum_0, data_0 ;accum =  -/64k + /2 - /512 + /4 + /512k + /4k + 32
	
	BCF	STATUS, C
	RRFc	data_0	;/64
	;			     		 + 16k			
	; /2 + /4 + /32 + /128 - /512 + /4096 + /16k - /64k + /512k
			
	MOVF	data_1, W
	ADDWF	accum_0, F
	BR_NC	t5_4
	INCF	accum_1, F
	SK_NZ
	INCF	accum_2, F
t5_4
	MOVF	data_2, W
	ADDWF	accum_1, F
	SK_NC
	INCF	accum_2, F  ;accum =  -/64k + /2 - /512 + /4 + /512k + /4k + +32 + 16k
	
	BCF	STATUS, C
	RRFc	data_0	;/128
	;		  + 128
	; /2 + /4 + /32 + /128 - /512 + /4096 + /16k - /64k + /512k
	
	ADDc	accum_0, data_0  ;accum =  -/64k + /2 - /512 + /4 + /512k + /4k +32 + 16k + 128
	
	BTFSS	accum_0, 0 ; check for 0.5 end
	GOTO	t5_end	
	INCFc	accum_0	; inc to round up

t5_end:
	BCF	STATUS, C
	RRFc	accum_0	; div / 2

; original very long code with a lot of shift
	; BCF	STATUS, C
	; RRFc	data_0	;/2
	; MOVc	data_0, accum_0
	
	; BCF	STATUS, C
	; RRFc	data_0	;/4
	; ADDc	accum_0, data_0 ;accum = d/2 + d/4
	
	; STR	3, div_loop	;3
; t5_32:
	; BCF	STATUS, C
	; RRFc	data_0	;/8 /16 /32
	
	; DECFSZ	div_loop, F
	; GOTO	t5_32	
	; ADDc	accum_0, data_0 ; accum = d/2 + d/4 + d/32

	; BCF	STATUS, C
	; RRFc	data_0	;/64
	; BCF	STATUS, C
	; RRFc	data_0	;/128
	; ADDc	accum_0, data_0 ; accum = d/2 + d/4 + d/32 + d/128
	
	; BCF	STATUS, C
	; RRFc	data_0	;/256
	; BCF	STATUS, C
	; RRFc	data_0	;/512
	; SUBc	accum_0, data_0 ; accum = d/2 + d/4 + d/32 + d/128 - d/512
	
	; STR	3, div_loop	;3
; t5_4096:
	; BCF	STATUS, C
	; RRFc	data_0	;/1024 /2048 /4096
	
	; DECFSZ	div_loop, F
	; GOTO	t5_4096	
	; ADDc	accum_0, data_0 ; accum = d/2 + d/4 + d/32 + d/128 - d/512 + d/4096
	
	; BCF	STATUS, C
	; RRFc	data_0	;/8k
	; BCF	STATUS, C
	; RRFc	data_0	;/16k
	; ADDc	accum_0, data_0 ; accum = d/2 + d/4 + d/32 + d/128 - d/512 + d/4096 + d/16k
	
	; BCF	STATUS, C
	; RRFc	data_0	;/32k
	; BCF	STATUS, C
	; RRFc	data_0	;/64k
	; SUBc	accum_0, data_0 ; accum = d/2 + d/4 + d/32 + d/128 - d/512 + d/4096 + d/16k - 64k
	
	; BTFSS	accum_0, 0 ; check for 0.5 end
	; GOTO	t5_end	
	; INCFc	accum_0	; inc to round up

; t5_end:
	; BCF	STATUS, C
	; RRFc	accum_0	; div / 2


;*****	TEST 5 STOP **** 
	BCF	T1CON, TMR1ON	; timer1 OFF	
	MOVF	PCLATH, W
	ADDWF	inst_count_1, F
	MOVF	PCL, W
	ADDWF	inst_count_0, F
	
	MOVLW	HIGH (loop)
	MOVWF	PCLATH
	RETURN
	
	
test6:
	PC0x0100SKIP
	BSF	T1CON, TMR1ON	; timer1 ON

	; result is data * 100 / 254
	; data = data * 100
	; accum = ROUND(data / 256)
	; accum = accum + ROUND(accum / 32k)
	; accum = accum + FLOOR(accum / 4m)
	; good up to 24 inches
	
	BCF	STATUS, C
	RLFc	data_0 ;x2
	RLFc	data_0 ;x4
	MOVc	data_0, accum_0 ; accum is data * 4
			
	BCF	STATUS, C
	RLFc	data_0 ;x8
	RLFc	data_0 ;x16
	RLFc	data_0 ;x32		
	ADDc	accum_0, data_0 ; accum is data * 4 + data * 32
	
	BCF	STATUS, C
	RLFc	data_0 ;x64
	ADDc	data_0, accum_0 ; data is data * 4 + data * 32 + data * 64 = (100 * data)

;         no shift,	1byte,	2byte
; no bit shift  /1	/256	/64k	0
; after /2      /2	/512	/128k	1
; after /4      /4	/1024	/256k	2
; after /8      /8	/2k	/512k	3
; after /16	 /16	/4k	/1m	4
; after /32	 /32	/8k	/2m	5
; after /64	 /64	/16k	/4m*	6
; after /128	/128	/32k*	/8m	7

; after /256 	/256*	/64k	/16m	byte shift

	MOVF	data_0, W
	MOVWF	data_f		; keep fraction
	MOVF	data_1, W
	MOVWF	data_0
	MOVF	data_2, W
	MOVWF	data_1		 
	CLRF	data_2		 ; data = data / 256
	
	BTFSS	data_f, 7	; check if end in 0.5
	GOTO	t6_0
	INCFc	data_0		; round up	
t6_0:
	MOVc	data_0, accum_0 ; accum = ROUND(data / 256)
	
	; 64 aa bb /256
	; 00 64 aa /256 (/64k)
	; 00 00 64 aa *2
	; 00 00 C8 bb (/32k)

	MOVF	data_0, W
	MOVWF	data_f		; keep fraction
	MOVF	data_1, W
	MOVWF	data_0
	MOVF	data_2, W
	MOVWF	data_1		 
	CLRF	data_2		 ; data = data / 256 (total of 64k)
	
	BCF	STATUS, C
	RLFi	data_f		; 32 bit integer x2, data, is now data / 256 / 256 x2 or /32k
	
	BTFSS	data_f, 7	; check if end in 0.5
	GOTO	t6_1
	INCFc	data_0		; round up	
t6_1:
	ADDc	accum_0, data_0 ; accum = ROUND(data / 256) + ROUND(data / 32k)
	
	; 64 aa bb /256
	; 00 64 aa /256 (/64k)
	; 00 00 64 aa *2
	; 00 00 C8 bb (/32k)
	; 00 00 00 C8 bb /256 (8m)
	; 00 00 01 90 00 *2 (4m)

	MOVF	data_0, W
	MOVWF	data_f		; keep fraction
	MOVF	data_1, W
	MOVWF	data_0
	MOVF	data_2, W
	MOVWF	data_1		 
	CLRF	data_2		 ; data = data/32 / 256 (total of 8m)
	
	BCF	STATUS, C
	RLFi	data_f		; 32 bit integer x2, data, is now data / 4m
	
	ADDc	accum_0, data_0 ; accum = ROUND(data / 256) + ROUND(data / 32k) + FLOOR(data / 4m)


;*****	TEST 6 STOP **** 
	BCF	T1CON, TMR1ON	; timer1 OFF	
	MOVF	PCLATH, W
	ADDWF	inst_count_1, F
	MOVF	PCL, W
	ADDWF	inst_count_0, F
	
	MOVLW	HIGH (loop)
	MOVWF	PCLATH
	RETURN
	
	
	
; < DIV25.4
; pre optimization 1
 ; t00A
; < 0 i0073 r0003E8
; > 04 00 00 00
; <  t02BD i004C r
; < 000
; < 000
; > 04 00 63 38
; <  t02EA i004C r
; < 000
; < 064
; > 04 26 C1 E0
; <  t0308 i004C r
; < 002
; < 710
; < ?
; < ?
; < ?
; < DIV25.4

 ; t00A
; < 0 i0073 r0003E8
; > 04 26 C1 E0
; <  t0366 i0074 r
; < 018
; < 6A0
; after opt 1, remove shifting by pre calculating index and divisor
; < DIV25.4

 ; t00A
; < 0 i0073 r0003E8
; > 04 03e030
; <  t0295 i005F r
; < 002
; < 710
; > 04 00 00 02
; <  t0248 i005F r
; < 000
; < 000
; > 04 00 FF 02
; <  t0286 i005F r
; < 000
; < A0A
; > 04 00 63 38
; <  t02A6 i005F 
; < r000
; < 3E8
; > 04 26 c1 e0
; <  t02A6 i005F 
; < r018
; < 6A0
	
;#############################################################################
;	End Declaration
;#############################################################################

	END


; < DIV25.4
 ; t00A0 i0073 r0003E8
; > 03 00 63 38
 ; t0113 i00C3 r0003E8
; > 00 00 63 38
 ; t0001 i0001 r000000
; > 01 00 63 38
 ; t00A0 i0073 r0003E8
; > 02 00 63 38
 ; t00E4 i00A4 r0003EA
; > 03 00 63 38
 ; t0113 i00C3 r0003E8
; > 01 26 C1 E0
 ; t00A4 i0073 r018734
; > 02 26 C1 E0
 ; t00E4 i00A4 r01869C
; > 03 26 C1 E0
 ; t0113 i00C3 r0186AD
;
; target for 00 63 38 -> 0003E8
; target for 26 C1 E0 -> 0186A0
;
; 1 / 254 = 0,0039370078740157
; 0.500
; 0.250
; 0.125
	; 25400.0000	times 25400	12700.0000	19050.0000	19843.7500	20042.2002	19992.5908	19998.791996875	20000.342289844	19999.954716602
		; err	0.2874	0.0374	0.0062	-0.0017	0.0003	0.00004756	-0.00001348	0.00000178
		; sum	0.500000	0.750000	0.781250	0.789063	0.787110	0.78735402	0.78741505	0.78739979
				; +	+	+	-	+	+	-
	; target is 1/1.27:	0.787402	0.500000	0.250000	0.031250	0.007813	0.001953	0.00024414	0.00006104	0.00001526
; div	bitshift		2	4	32	128	512	4096	16384	65536





