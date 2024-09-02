;#############################################################################
;
;	BIN 2 BCD test
;	blocking sync UART with CTS flow control
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
; pin 17 IOA PORTA0	O UART CTS
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
test_index		EQU	0x23
inst_count_0		EQU	0x24
inst_count_1		EQU	0x25
serial_count		EQU	0x26
serial_data		EQU	0x27

data_f			EQU	0x30
data_0			EQU	0x31
data_1			EQU	0x32
data_2			EQU	0x33
data_3			EQU	0x34

accum_f			EQU	0x35
accum_0			EQU	0x36
accum_1			EQU	0x37
accum_2			EQU	0x38
accum_3			EQU	0x39

temp_f			EQU	0x3A
temp_0			EQU	0x3B
temp_1			EQU	0x3C
temp_2			EQU	0x3D
temp_3			EQU	0x3E

data_BCDf		EQU	0x3F
data_BCD0		EQU	0x40
data_BCD1		EQU	0x41
data_BCD2		EQU	0x42
data_BCD3		EQU	0x43

;#############################################################################
;	MACRO
;#############################################################################

WRITELN_BLOCK	MACRO string
	LOCAL	_END, _TABLE, _NEXT
	
	IF 	( _END & 0xFFFFFF00 ) != ( $ & 0xFFFFFF00 )
	ORG	( $ & 0xFFFFFF00 ) + 0x0100
	ENDIF	; boundary check
	
	MOVLW	high (_TABLE)
	MOVWF	PCLATH
	CLRF	serial_count
_NEXT:
	MOVF	serial_count, W
	CALL 	_TABLE
	ANDLW	0xFF
	BTFSC	STATUS, Z
	GOTO	_END

	BTFSS	PIR1, TXIF
	GOTO	$ - 1
	MOVWF	TXREG
	
	INCF	serial_count, F
	GOTO	_NEXT
_TABLE:
	ADDWF	PCL, F
	DT	string, 13, 10, 0
_END:
	ENDM
	
SENDW	MACRO
	BTFSS	PIR1, TXIF
	GOTO	$ - 1
	MOVWF	TXREG
	ENDM
	
SENDI	MACRO	i
	MOVLW	i
	BTFSS	PIR1, TXIF
	GOTO	$ - 1
	MOVWF	TXREG
	ENDM

SENDOEL	MACRO	
	MOVLW	0x0D
	BTFSS	PIR1, TXIF
	GOTO	$ - 1
	MOVWF	TXREG
	MOVLW	0x0A
	BTFSS	PIR1, TXIF
	GOTO	$ - 1
	MOVWF	TXREG
	ENDM
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
	CALL	WAIT_1s	
	
	WRITELN_BLOCK	"Test 00 NOP, 01 BCD2BIN, 02 MULT_2p54"

	
	STRc	0x000064, data_BCD0 ; x64 100 -> 254 0x0000FE 
	STR	2, test_index

loop:
	CLRF	TMR1L
	CLRF	TMR1H
	CLRF	inst_count_0	
	CLRF	inst_count_1
	CLRFi	accum_0
	CLRFi	data_0

loop_t0:
	CMP_lf	0, test_index
	BR_NE	loop_t1
	MOVLW	HIGH ( test0 )	
	MOVWF	PCLATH
	CALL	test0
	SUBLs	inst_count_0, test0
	GOTO	loop_end
	
loop_t1:
	CMP_lf	1, test_index
	BR_NE	loop_t2
	MOVLW	HIGH ( test1 )
	MOVWF	PCLATH
	CALL	test1
	SUBLs	inst_count_0, test1
	GOTO	loop_end
	
loop_t2:
	CMP_lf	2, test_index
	BR_NE	loop_t3
	MOVLW	HIGH ( test2 )
	MOVWF	PCLATH
	CALL	test2
	SUBLs	inst_count_0, test2
	GOTO	loop_end
	
loop_t3:
	CMP_lf	3, test_index
	BR_NE	loop_t4
	MOVLW	HIGH ( test3 )
	MOVWF	PCLATH
	CALL	test3
	SUBLs	inst_count_0, test3
	GOTO	loop_end
	
loop_t4:
	CMP_lf	4, test_index
	BR_NE	loop_t5
	MOVLW	HIGH ( test4 )
	MOVWF	PCLATH
	CALL	test4
	SUBLs	inst_count_0, test4
	GOTO	loop_end

loop_t5:
	CMP_lf	5, test_index
	BR_NE	loop_t6
	MOVLW	HIGH ( test5 )
	MOVWF	PCLATH
	CALL	test5
	SUBLs	inst_count_0, test5
	GOTO	loop_end
	
loop_t6:
	CMP_lf	6, test_index
	BR_NE	loop_notfound
	MOVLW	HIGH ( test6 )
	MOVWF	PCLATH
	CALL	test6
	SUBLs	inst_count_0, test6
	GOTO	loop_end
	
loop_notfound:
	SENDi	'e'
	SENDi	'r'
	SENDi	'r'
	GOTO	waitnext
	
loop_end:
	BTFSS	PIR1, TMR1IF
	GOTO	div_noOverflow
	SENDi	'o'
	SENDi	'f'
	SENDi	' '
	BCF	PIR1, TMR1IF
		
div_noOverflow:
	; send results
	MOVLW	HIGH( table_nibbleHex )
	MOVWF	PCLATH	
	
	; instructions
	SENDi	'i'	
	MOVLW	inst_count_1
	MOVWF	FSR
	CALL	SEND2HEX
	
	; time
	SENDi	' '	
	SENDi	't'
	
	MOVLW	TMR1H
	MOVWF	FSR
	CALL	SEND2HEX
	
	; result	
	SENDi	' '
	SENDi	'r'
	
	MOVLW	data_3
	MOVWF	FSR
	CALL	SEND4HEX
	
waitnext:
	SENDOEL	
	
	; wait for next test	
	CALL	WAIT_BYTE
	MOV	serial_data, test_index
	
	CLRF	data_BCD3
	
	CALL	WAIT_BYTE
	MOV	serial_data, data_BCD2
	
	CALL	WAIT_BYTE
	MOV	serial_data, data_BCD1
	
	CALL	WAIT_BYTE
	MOV	serial_data, data_BCD0
	
	MOVLW	0x04
	XORWF	PORTA, F

	GOTO	loop

; send hex data, MSB first, FSR point to LAST BYTE
SEND4HEX:
	SWAPF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	BTFSS	PIR1, TXIF
	GOTO	$ - 1
	MOVWF	TXREG
	
	MOVF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	BTFSS	PIR1, TXIF
	GOTO	$ - 1
	MOVWF	TXREG
	
	DECF	FSR, F
SEND3HEX:
	SWAPF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	BTFSS	PIR1, TXIF
	GOTO	$ - 1
	MOVWF	TXREG
	
	MOVF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	BTFSS	PIR1, TXIF
	GOTO	$ - 1
	MOVWF	TXREG
	
	DECF	FSR, F
SEND2HEX:
	SWAPF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	BTFSS	PIR1, TXIF
	GOTO	$ - 1
	MOVWF	TXREG
	
	MOVF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	BTFSS	PIR1, TXIF
	GOTO	$ - 1
	MOVWF	TXREG
	
	DECF	FSR, F
SEND1HEX:
	SWAPF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	BTFSS	PIR1, TXIF
	GOTO	$ - 1
	MOVWF	TXREG
	
	MOVF	INDF, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	BTFSS	PIR1, TXIF
	GOTO	$ - 1
	MOVWF	TXREG
	
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
	GOTO	$ - 1
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
	BSF	T1CON, TMR1ON	; timer1 ON
;****	TEST 0 START ****

	NOP
	
;*****	TEST 0 STOP **** 
	BCF	T1CON, TMR1ON	; timer1 OFF	
	STRs	( $ - 2 ), inst_count_0
	RETURN
	
test1:
	BSF	T1CON, TMR1ON	; timer1 ON
;*****	TEST 1 START **** 
;#############################################################################
;	BCD to 20 bits
;	max is 99999 or 0x01869F
;	Data in data_BCD2.data_BCD1.data_BCD0
;	Output in data_2.data_1.data_0
;	Temporary accum_2.accum_1.accum_0
;#############################################################################

	CLRFc	data_0
	
	MOVLW	0x0F
	ANDWF	data_BCD2, W ;	select low nibble
	MOVWF	data_0
	CALL	test1_BCD2BIN_x10
	
	SWAPF	data_BCD1, W
	ANDLW	0x0F
	CALL	test1_BCD2BIN_addW_x10
	
	MOVF	data_BCD1, W
	ANDLW	0x0F
	CALL	test1_BCD2BIN_addW_x10
	
	SWAPF	data_BCD0, W
	ANDLW	0x0F
	CALL	test1_BCD2BIN_addW_x10
	
	MOVF	data_BCD0, W
	ANDLW	0x0F
	ADDWF	data_0, F
	BTFSS	STATUS, C
	GOTO	test1_end
	INCF	data_1, F
	BTFSC	STATUS, Z
	INCF	data_2, F
	
	GOTO	test1_end
	
test1_BCD2BIN_addW_x10:
	ADDWF	data_0, F
	BTFSS	STATUS, C
	GOTO	test1_BCD2BIN_x10
	INCF	data_1, F
	BTFSC	STATUS, Z
	INCF	data_2, F	

test1_BCD2BIN_x10:	; multiply data x 10
	BCF	STATUS, C
	RLFc	data_0 ; x2
	MOVc	data_0, accum_0
	
	BCF	STATUS, C
	RLFc	data_0 ; x4
	BCF	STATUS, C
	RLFc	data_0 ; x8
	ADDc	data_0, accum_0 ; data = data*8 + data*2
	RETURN
	
test1_end:
;*****	TEST 1 STOP **** 
	BCF	T1CON, TMR1ON	; timer1 OFF	
	STRs	( $ - 2 ), inst_count_0	
	RETURN
	
test2:
	BSF	T1CON, TMR1ON	; timer1 ON
;*****	TEST 2 START **** 

	; for testing data input is in data_BCD	
	MOVc	data_BCD0, data_0
	; dosent work up to 99999  0x01 86 9F
	; mult 100 0x00 98 96 1C
;#############################################################################
;	mult * 2.54
;	input in data_2.data_1.data_0
;	output in data_2.data_1.data_0
;	temporary in accum_2.accum_1.accum_0
;			data_f
;			temp_2.temp_1.temp_0
;#############################################################################
MULT_2p54:

	CLRF	data_3
	MOV	data_2, accum_3
	MOV	data_1, accum_2
	MOV	data_0, accum_1
	CLRF	accum_0		 ; accum = data x 256

	BCF	STATUS, C	
	RLFi	data_0		 ; data = data x 2
	SUBi	accum_0, data_0 ; accum = (data*256) - (data*2) = data*254

; DIV 100
; 128	512	4096	-131072	-524288	-4194304
; all rounded up 
;         no shift,	1byte,	2byte
; no bit shift  /1	/256	/64k	0
; after /2      /2	/512*	/128k*	1
; after /4      /4	/1024	/256k	2
; after /8      /8	/2k	/512k*	3
; after /16	 /16	/4k*	/1m	4
; after /32	 /32	/8k	/2m	5
; after /64	 /64	/16k	/4m*	6
; after /128*	/128	/32k	/8m	7
; after /256 	/256	/64k	/16m	byte shift

	; for rounding 
	CLRF	temp_f
	CLRF	temp_0
	CLRF	temp_1
	CLRF	temp_2
	CLRF	temp_3
	decf 	temp_3


	MOV	accum_0, data_f
	MOV	accum_1, data_0
	MOV	accum_2, data_1
	MOV	accum_3, data_2
	CLRF	data_3
	; data = data/256
	
	BCF	STATUS, C
	RLFi	data_f
	MOVi	data_f, temp_f
	; data = data/256 * 2 == data / 128
	BTFSS	temp_f,  7
	GOTO 	MULT_2p54_1
	INCFc	temp_0		; temp = round (data/128)
MULT_2p54_1:
	MOVc	temp_0, accum_0 ;accum = Round(data / 128)
	
	BCF	STATUS, C
	RRFi	data_f ;/2  data = data / 256
	BCF	STATUS, C
	RRFi	data_f ;/2  data = data / 512
	MOVi	data_f, temp_f
	
	BTFSS	temp_f,  7	; round up
	GOTO 	MULT_2p54_2
	INCFc	temp_0		; temp = round(data/512)
MULT_2p54_2:
	ADDc	accum_0, temp_0 ;accum = Round(data / 128) + Round(data/512)
	
	;CLRF	temp_3
	MOVi	data_0, temp_f ; temp = data / 512 / 256 = data / 128k
	BTFSS	temp_f,  7	; round up
	GOTO 	MULT_2p54_3
	INCFc	temp_0		; temp = round(data/128k)
MULT_2p54_3:
	SUBc	accum_0, temp_0 ; accum = Round(data/128) + Round(data/512) - Round(data/128k)
	
	BCF	STATUS, C
	RRFi	data_f ;/2  data = data / 1024
	BCF	STATUS, C
	RRFi	data_f ;/2  data = data / 2k
	;CLRF	temp_3
	MOVc	data_0, temp_f ; temp = data / 2k / 256 = data / 512k
	BTFSS	temp_f,  7	; round up
	GOTO 	MULT_2p54_4
	INCFc	temp_0		; temp = round(data/512k)
MULT_2p54_4:
	SUBc	accum_0, temp_0 ; accum = Round(data/128) + Round(data/512) - Round(data/128k) - Round(data/512k)
	
	BCF	STATUS, C
	RRFi	data_f ;/2  data = data /4k
	
	MOVi	data_f, temp_f ; temp = data / 2k / 256 = data / 512k
	BTFSS	temp_f,  7	; round up
	GOTO 	MULT_2p54_5
	INCFc	temp_0		; temp = round(data/4k)
MULT_2p54_5:
	ADDc	accum_0, temp_0 ;accum = Round(data/128) + Round(data/512) - Round(data/128k) - Round(data/512k) + Round(data/4k)

	BCF	STATUS, C
	RRFi	data_f ;/2  data = data /8k
	
	BCF	STATUS, C
	RRFi	data_f ;/2  data = data /16k
	
	MOVi	data_0, temp_f ; temp = data /16k /256 = data / 4m
	
	BTFSS	temp_f,  7	; round up
	GOTO 	MULT_2p54_6
	INCFc	temp_0		; temp = round(data/4k)
MULT_2p54_6:
	SUBc	accum_0, temp_0 ;accum = Round(data/128) + Round(data/512) - Round(data/128k) - Round(data/512k) + Round(data/4k) - Round(data/4m)
	
	MOVc	accum_0, data_0


test2_end:
;*****	TEST 2 STOP **** 
	BCF	T1CON, TMR1ON	; timer1 OFF	
	STRs	( $ - 2 ), inst_count_0
	RETURN










test3:
	BSF	T1CON, TMR1ON	; timer1 ON
;*****	TEST 3 START **** 


;*****	TEST 3 STOP **** 
	BCF	T1CON, TMR1ON	; timer1 OFF	
	STRs	( $ - 2 ), inst_count_0
	RETURN
	
	
test4:
	BSF	T1CON, TMR1ON	; timer1 ON
;*****	TEST 4 START **** 

;*****	TEST 4 STOP **** 
	BCF	T1CON, TMR1ON	; timer1 OFF	
	STRs	( $ - 2 ), inst_count_0
	RETURN
	
test5:
	BSF	T1CON, TMR1ON	; timer1 ON
;*****	TEST 5 START **** 

;*****	TEST 5 STOP **** 
	BCF	T1CON, TMR1ON	; timer1 OFF	
	STRs	( $ - 2 ), inst_count_0
	RETURN
	
	
test6:
	BSF	T1CON, TMR1ON	; timer1 ON
;*****	TEST 6 START **** 

;*****	TEST 6 STOP **** 
	BCF	T1CON, TMR1ON	; timer1 OFF	
	STRs	( $ - 2 ), inst_count_0
	RETURN
	

	
;#############################################################################
;	End Declaration
;#############################################################################

	END


