;#############################################################################
;	GPS Speed display 1
;	7 segments display of GPS speed data in KM/H trough 74LS47
;	4 digits, 000.0 to 999.9
;	could be used to implement climb rate
;#############################################################################

	LIST	p=16F88			; processor model
#INCLUDE	<P16F88.INC>		; processor specific variable definitions
#INCLUDE	<PIC16F88_Macro.asm>	; base macro for banks, context, branchs
#INCLUDE	<PIC16F88_MacroExt.asm> ; 16/24/32 bit instructions extensions

;#############################################################################
;	Configuration
;#############################################################################

	__CONFIG	_CONFIG1, 	_CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & _WDT_OFF & _INTRC_IO
	__CONFIG	_CONFIG2, 	_IESO_OFF & _FCMEN_OFF

;#############################################################################
;	Pinout
;#############################################################################

; PIC16F88:
; pin  1 IOA PORTA2	O BCD bit 2 
; pin  2 IOA PORTA3	O BCD bit 3
; pin  3 IOA PORTA4	I 
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O Digit select 0
; pin  7 IO_ PORTB1	O Digit select 1
; pin  8 IOR PORTB2	I RX from GPS
; pin  9 IO_ PORTB3	O Digit select 2

; pin 10 IO_ PORTB4	O Digit select 3
; pin 11 IOT PORTB5	O TX to computer
; pin 12 IOA PORTB6	I ICSP PGC
; pin 13 IOA PORTB7	I ICSP PGD
; pin 14 PWR VDD	VCC
; pin 15 _O_ PORTA6	         (XT 18.432MHz, wait_1s at 23)
; pin 16 I__ PORTA7	         (XT Low BRGH, @29 for 9600)
; pin 17 IOA PORTA0	O BCD bit 0
; pin 18 IOA PORTA1	O BCD bit 1


#DEFINE DigitSelect0		PORTB, 0
#DEFINE DigitSelect1		PORTB, 1
#DEFINE DigitSelect2		PORTB, 3
#DEFINE DigitSelect3		PORTB, 4

#DEFINE	END_MARKER		0xFF
#DEFINE	CONV_DOT		'.' - '0'
#DEFINE	CONV_MINUS		'-' - '0'

#DEFINE	SERIAL_DEBUG

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

; Bank 0 0x20 - 0x6F

WAIT_loopCounter1	EQU	0x20
WAIT_loopCounter2	EQU	0x21
WAIT_loopCounter3	EQU	0x22

Serial_Data		EQU	0x23
Serial_Status		EQU	0x24

_Serial_bit_RX_frameError 		EQU	0	;uart module frame error
_Serial_bit_RX_overrunError 		EQU	1	;uart module overrun error
_Serial_bit_RX_bufferOverrun 		EQU	2	;RX circular buffer overrun error
_Serial_bit_RX_inhibit		EQU	3	;discard RX data

WriteLoop		EQU	0x25
TX_Temp			EQU	0x26
;			EQU	0x27
;			EQU	0x28
;			EQU	0x29

data_buffer		EQU	0x2A ; 0x2A to 0x3E -> 20 bytes
;			EQU	0x2B
;			EQU	0x2C
;			EQU	0x2D
;			EQU	0x2E
;			EQU	0x2F
;			EQU	0x30
;			EQU	0x31
;			EQU	0x32
;			EQU	0x33
;			EQU	0x34
;			EQU	0x35
;			EQU	0x36
;			EQU	0x37
;			EQU	0x38
;			EQU	0x39
;			EQU	0x3A 
;			EQU	0x3B
;			EQU	0x3C
;			EQU	0x3D
;			EQU	0x3E

BCD_Result		EQU	0x3F ; 0x40 0x41 0x42 for 8 bcd nibbles, up to 16 77 72 15 (24 bit to bcd)
;			EQU	0x40
;			EQU	0x41
;			EQU	0x42

D88_Fract		EQU	0x43 ; 0x44 0x45 resulting fraction of div
;			EQU	0x44
;			EQU	0x45

D88_Modulo		EQU	0x46 ; 0x47 0x48 Modulo for preset div, also index for arbitrary div
;			EQU	0x47
;			EQU	0x48

D88_Num			EQU	0x49 ; 0x4A 0x4B 0x4C numerator for div and receive modulo (remainder)
;			EQU	0x4A
;			EQU	0x4B
;			EQU	0x4C

D88_Denum		EQU	0x4D ; 0x4E 0x4F 0x50 denumerator for div
;			EQU	0x4E
;			EQU	0x4F
;			EQU	0x50

DigitCount		EQU	0x51
IntToConvert		EQU	0x52 ; 0x53 0x54 0x55 for convert to hex or BCD
;			EQU	0x53
;			EQU	0x54
;			EQU	0x55

;			EQU	0x56
;			EQU	0x57
;			EQU	0x58

NixieVarX		EQU	0x59 ; local var
NixieVarY		EQU	0x5A ; loval var
NixieLoop		EQU	0x5B ; local var
;NixieSeg		EQU	0x5C ; to pass data between routines
;NixieData		EQU	0x5D ; to pass data between routines
;NixieTube		EQU	0x5E ; to pass data between routines
;NixieDemoCount	EQU	0x5F ; global for demo and "no data" display

Digit0			EQU	0x60 ; 100
Digit1			EQU	0x61 ; 10
Digit2			EQU	0x62 ; 1
Digit3			EQU	0x63 ; 1/10th km/h

;			EQU	0x64
;			EQU	0x65
;			EQU	0x66
;			EQU	0x67

;			EQU	0x68
;			EQU	0x69
;			EQU	0x6A
;			EQU	0x6B

;			EQU	0x6C

; GPR files in GPR for context saving
;STACK_FSR		EQU	0x6D
;STACK_SCRATCH		EQU	0x6E
;STACK_PCLATH		EQU	0x6F



; Bank 1 0xA0 - 0xEF

_Serial_RX_buffer_startAddress	EQU	0xA0 ; circular RX buffer start
_Serial_RX_buffer_endAddress		EQU	0xC0 ; circular RX buffer end + 1

_Serial_TX_buffer_startAddress	EQU	0xC0 ; circular TX buffer start
_Serial_TX_buffer_endAddress		EQU	0xE0 ; circular TX buffer end + 1

;			EQU	0xE0 

;			EQU	0xEA
;			EQU	0xEB
;			EQU	0xEC

;			EQU	0xED
;			EQU	0xEE
;			EQU	0xEF

; Bank 2 0x110 - 0x16F
; Bank 3 0x180 - 0x18F

;#############################################################################
;	Shared Files 0x70 - 0x7F / 0xF0 - 0xFF / 0x170 - 0x17F / 0x1F0 - 0x1FF 
;#############################################################################

Serial_RX_buffer_rp	EQU	0x70 ; circular RX buffer read pointer
Serial_RX_buffer_wp	EQU	0x71 ; circular RX buffer write pointer

Serial_TX_buffer_rp	EQU	0x72 ; circular TX buffer read pointer
Serial_TX_buffer_wp	EQU	0x73 ; circular TX buffer write pointer

;			EQU	0x74
;			EQU	0x75
;			EQU	0x76
;			EQU	0x77

;			EQU	0x78
;			EQU	0x79
;			EQU	0x7A
;			EQU	0x7B

;			EQU	0x7C

; GPR files in shared GPR for instruction extensions
;SCRATCH		EQU	0x7D

; GPR files in shared GPR for context saving
;STACK_STATUS		EQU	0x7E
;STACK_W		EQU	0x7F


;#############################################################################
;	Reset Vector - Main Entry Point
;#############################################################################

	ORG	0x0000
	GOTO	SETUP

;#############################################################################
;	Interrupt Vector - Interrupt Service Routine
;#############################################################################

	ORG	0x0004
	PUSH

	BTFBS	PIR1, TMR1IF, ISR_T1

	GOTO	ISR_END 		; unkown interrupt

ISR_T1:
	BCF	PIR1, TMR1IF

	STR	b'11110000', TMR1H

	;reset digit selection
	BSF	DigitSelect0
	BSF	DigitSelect1
	BSF	DigitSelect2
	BSF	DigitSelect3

	;BCF	STATUS, C
	;RLF	DigitCount, F	;x2
	;RLF	DigitCount, F 	;x4
	
	;MOVF	DigitCount, W

	;PC0x0100ALIGN ISR_T1_vectors
ISR_T1_vectors:
	;ADDWF	PCL, F
	
	;BCF	DigitSelect0
	;MOVF	Digit0, W
	;MOVWF	PORTA
	;GOTO	ISR_T1b
	
	;BCF	DigitSelect1
	;MOVF	Digit1, W
	;MOVWF	PORTA
	;GOTO	ISR_T1b
	
	;BCF	DigitSelect2
	;MOVF	Digit2, W
	;MOVWF	PORTA
	;GOTO	ISR_T1b
	
	;BCF	DigitSelect3
	;MOVF	Digit3, W
	
	;MOVWF	PORTA
	
	CMP_LF	0, DigitCount
	BR_EQ	ISR_T1_0
	CMP_LF	1, DigitCount
	BR_EQ	ISR_T1_1
	CMP_LF	2, DigitCount
	BR_EQ	ISR_T1_2
	CMP_LF	3, DigitCount
	BR_EQ	ISR_T1_3
	
	BCF	DigitSelect0
	BCF	DigitSelect1
	BCF	DigitSelect2
	BCF	DigitSelect3
	GOTO	ISR_END
	
ISR_T1_0:
	BCF	DigitSelect0
	MOVF	Digit0, W
	MOVWF	PORTA
	GOTO	ISR_T1b
	
ISR_T1_1:
	BCF	DigitSelect1
	MOVF	Digit1, W
	MOVWF	PORTA
	GOTO	ISR_T1b
	
ISR_T1_2:
	BCF	DigitSelect2
	MOVF	Digit2, W
	MOVWF	PORTA
	GOTO	ISR_T1b
	
ISR_T1_3:
	BCF	DigitSelect3
	MOVF	Digit3, W
	MOVWF	PORTA
	GOTO	ISR_T1b

ISR_T1b:
	INCF	DigitCount, F
	CMP_LF	4, DigitCount
	SK_NE
	CLRF	DigitCount
	
ISR_END:	

	POP
	RETFIE

;#############################################################################
;	Initial Setup
;#############################################################################

SETUP:

	BANK1

	; init port directions
	CLRF	TRISA		; all outputs

	CLRF	TRISB		; all outputs
	;BSF	TRISB, 2	; Bit2 is input (RX)


	; init analog inputs
	CLRF	ANSEL		; all digital

	; init osc 8MHz
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2

	; init AUSART transmitter
	;BCF 	TXSTA, TX9	; 8 bit tx
	;BSF	TXSTA, TXEN	; enable tx
	;BCF	TXSTA, SYNC	; async

	; set 9600 baud rate for 8MHz clock
	;BSF 	TXSTA, BRGH	; high speed baud rate generator
	;MOVLW	51		; 9600 bauds
	;MOVWF	SPBRG

	;BCF	PIE1, RCIE	; disable rx interrupts
	;BCF	PIE1, TXIE	; disable tx interrupts
	BSF	PIE1, TMR1IE	; enable timer1 interrupts
	
	BANK0
	
	; at 8x prescaler, 8mhz crystal, 2mhz instruction clock, 3.8hz timer1 overflow
	CLRF	TMR1L
	CLRF	TMR1H
	BCF	T1CON, T1CKPS0	; 
	BCF	T1CON, T1CKPS1	;
	BCF	T1CON, TMR1CS	; timer clock is FOSC/4
	BSF	T1CON, TMR1ON	; timer ON

	; init AUSART receiver
	;BSF	RCSTA, SPEN	; serial port enabled
	;BCF	RCSTA, RX9	; 8 bit rx
	;BSF	RCSTA, SREN	; not used in async - enable single receive
	;BSF	RCSTA, CREN	; enable continuous receive
	;BCF	RCSTA, ADDEN	; disable addressing

	; initialize circular buffer pointers
	;MOVLW	_Serial_RX_buffer_startAddress
	;MOVWF	Serial_RX_buffer_rp
	;MOVWF	Serial_RX_buffer_wp

	;MOVLW	_Serial_TX_buffer_startAddress
	;MOVWF	Serial_TX_buffer_rp
	;MOVWF	Serial_TX_buffer_wp

	CLRF	PORTA
	CLRF	PORTB

	;CLRF	Serial_Status
	;BSF	Serial_Status, _Serial_bit_RX_inhibit
	
	BSF	INTCON, GIE
	BSF	INTCON, PEIE

; enable interrupts


	;WRITESTRING_LN		"Speed Display 1 - 4 x 7 segments - 2023-06-25"



;#############################################################################
;	Main Loop
;#############################################################################
	STR	0, Digit0
	STR	1, Digit1
	STR	2, Digit2
	STR	3, Digit3
	CLRF	DigitCount
	
LOOP:
	; loop all digit displays with current data
	; after timeout update
	CALL	WAIT_1s

	MOV	Digit3,  NixieVarX
	MOV	Digit2,  Digit3
	MOV	Digit1,  Digit2
	MOV	Digit0,  Digit1
	MOV	NixieVarX,  Digit0
	;MOV	Digit0, PORTA
	;MOVLW	0
	;MOVWF	PORTA
	;CALL	WAIT_1s
	
	;MOVLW	1
	;MOVWF	PORTA
	;CALL	WAIT_1s
	
	;MOVLW	2
	;MOVWF	PORTA
	;CALL	WAIT_1s
	
	;MOVLW	3
	;MOVWF	PORTA
	;CALL	WAIT_1s
	
	GOTO	LOOP
	
;#############################################################################
;	End of main loop
;#############################################################################


;#############################################################################
;	Subroutines
;#############################################################################


;#############################################################################
;	Delay routines	for 8MHz
;#############################################################################

WAIT_1s:
	MOVLW	10
	MOVWF	WAIT_loopCounter1

WAIT_1s_loop1:
	MOVLW	200			; (1) for 100 ms
	MOVWF	WAIT_loopCounter2	; (1)

WAIT_1s_loop2:			; 0.5ms / loop1
	MOVLW	250 - 2			; (1) 250 loops of 4 cycles (minus 2 loop for setup and next loop)
	MOVWF	WAIT_loopCounter3	; (1)
	NOP				; (1)
	NOP				; (1)

WAIT_1s_loop3:			; 4 cycles per loop (2us / loop2)
	NOP				; (1)
	DECFSZ	WAIT_loopCounter3, F	; (1)
	GOTO	WAIT_1s_loop3		; (2)
	NOP				; (1)

	NOP				; (1)
	DECFSZ	WAIT_loopCounter2, F	; (1)
	GOTO	WAIT_1s_loop2		; (2)

	DECFSZ	WAIT_loopCounter1, F
	GOTO	WAIT_1s_loop1
	RETURN



;#############################################################################
;	End Declaration
;#############################################################################

	END
