;#############################################################################
;
;	Lathe DRO control for chineese DRO scale
;	Read raidus and length
;	Display on 2 TM1637 6-digits 7-segments
;	Input with 4x4 keypad trough 74LS164 as https://hackaday.com/2015/04/15/simple-keypad-scanning-with-spi-and-some-hardware/
;
;#############################################################################
;
;	Version 1a
;	Basic 2 DRO scale sampling and output on UART at 9600 bauds
;
;;#############################################################################
;
;	radius to diameter
;	MM to IN
;	Invert direction done in software or dip switches
;	Set actual
;	Zero
;	Half function for mill 
;	
;	Test at 8MHz
;	?Upgrade to 20MHz crystal if enough pins avaiable
;	?Upgrade to 16F1459
;
;      7   8   9   X
;      4   5   6   Y
;      1   2   3   
;      U   0       OK
;
;      7   8   9   X
;      4   5   6   Y
;      1   2   3   Z
;      U   0  1/2  OK
;
;	select U to switch between IN and MM
;
;	select Axis
;	display 0
;  	  select OK to set to 0
;	  select any Axis to cancel
;
;	select Axis
;	display 0
;	  enter actual
;	    select OK to set to actual
;	    select any Axis to cancel
;
;	select Axis
;	display 0
;	  select 1/2
;	  display actual / 2
;	    select OK to set to 1/2
;	    select any Axis to cancel
;
; low of more than 0.5 ms is idle between 2 data packets
;
; Chineese DRO scane pinout
; USB mini B connector with fake pinout:
; Pin 1 (USB standard: VBUS RED)		Data
; Pin 2 (USB standard: DATA- WHITE)		Clock
; Pin 3 (USB standard: DATA+ GREEN)		Ground
; Pin 4 (USB standard: NC on device side)	Power 1.5V-3.0V
; Pin 5 (USB standard: GROUND BLACK)		NC

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
; pin  1 IOA PORTA2	I DRO0 CLOCK
; pin  2 IOA PORTA3	I DRO0 DATA
; pin  3 IOA PORTA4	
; pin  4 I__ PORTA5	MCLR (VPP)	; TODO change to keypad input
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O DISP Clock 
; pin  7 IO_ PORTB1	O DISP0 Data
; pin  8 IOR PORTB2	I UART RX
; pin  9 IO_ PORTB3	O DISP1 Data

; pin 10 IO_ PORTB4	
; pin 11 IOT PORTB5	O UART TX
; pin 12 IOA PORTB6	I ICSP PGC
; pin 13 IOA PORTB7	I ICSP PGD
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O ISR Status Bit
; pin 16 I_X PORTA7	
; pin 17 IOA PORTA0	I DRO1 CLOCK
; pin 18 IOA PORTA1	I DRO1 DATA


; V+ (square pad)
; Clock
; E
; Data
; GND

#DEFINE pin_DRO1_CLOCK	PORTA, 0
#DEFINE pin_DRO1_DATA		PORTA, 1
#DEFINE pin_DRO0_CLOCK	PORTA, 2
#DEFINE pin_DRO0_DATA		PORTA, 3
;#DEFINE LCD_Data		PORTA, 4
;#DEFINE MCLR			PORTA, 5
#DEFINE pin_ISR		PORTA, 6
;#DEFINE		PORTA, 7

;#DEFINE Scan_Clock		PORTB, 0
;#DEFINE Scan_Output		PORTB, 1
;#DEFINE Scan_Input		PORTB, 2
;#DEFINE 		PORTB, 3

;#DEFINE 		PORTB, 4
#DEFINE pin_UART_TX		PORTB, 5
;#DEFINE PGC			PORTB, 6
;#DEFINE PGD			PORTB, 7

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

WAIT_loopCounter1	EQU	0x20
WAIT_loopCounter2	EQU	0x21
WAIT_loopCounter3	EQU	0x22

read_loop		EQU	0x30

data_0			EQU	0x40
data_1			EQU	0x41
data_2			EQU	0x42

;#############################################################################
;	Reset Vector - Main Entry Point
;#############################################################################

	ORG	0x0000
	GOTO	SETUP

;#############################################################################
;	Interrupt Vector - Interrupt Service Routine
;#############################################################################

	ORG	0x0004
	BSF	pin_ISR
	GOTO	$ - 1		; ISR trap, should not be reachable
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
	
	BSF	pin_DRO0_CLOCK	; input
	BSF	pin_DRO0_DATA	; input
	BSF	pin_DRO1_CLOCK	; input
	BSF	pin_DRO1_DATA	; input

	; init osc 8MHz
	BCF	OSCCON, SCS0
	BCF	OSCCON, SCS1
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
SETUP_OSC:
	BTFSS	OSCCON, IOFS
	GOTO	SETUP_OSC
	
	; UART at 9600, 8 bits, async
	;BSF	TXSTA, CSRC	; not used in async - set as clock source master
	BCF 	TXSTA, TX9	; 8 bit tx
	BSF	TXSTA, TXEN	; enable tx
	BCF	TXSTA, SYNC	; async
	
	; set 9600 baud rate
	BSF 	TXSTA, BRGH	; high speed baud rate generator	
	MOVLW	51		; 9600 bauds
	MOVWF	SPBRG
	
	; timer 0
	BCF	OPTION_REG, T0CS ; on instruction clock
	BCF	OPTION_REG, PSA ; pre scaler assigned to tmr0
	BCF	OPTION_REG, PS2 ; 0
	BSF	OPTION_REG, PS1 ; 1
	BCF	OPTION_REG, PS0 ; 0 for 1:8 tmr0 ps
	; tmr0 overlfow every 8*256 instructions, or 2048 instructions / 1.024ms

	BCF	PIE1, TMR1IE	; TMR1 interrupt
	
	BANK0
	
	; ports
	CLRF	PORTA
	CLRF	PORTB	

	; timer1
	CLRF	TMR1L
	CLRF	TMR1H
	BCF	T1CON, T1CKPS0	; 0
	BSF	T1CON, T1CKPS1	; 1
	; pre scaler is 1:4, overlfow of 65536 instructions cycles is 131ms
	BCF	T1CON, TMR1CS	; timer1 clock is FOSC/4
	BSF	T1CON, TMR1ON	; timer1 ON
	
	; UART
	BSF	RCSTA, SPEN	; serial port enabled

	BCF	pin_ISR

; enable interrupts
	BCF	INTCON, PEIE ; enable peripheral int
	BCF	INTCON, TMR0IF; clear flag
	BCF	INTCON, TMR0IE; enable tmr0 interrupt
	CLRF	TMR0; clear tmr0

	BCF	INTCON, GIE
	
;#############################################################################
;	Main Loop
;#############################################################################
	CALL WAIT_50ms
MAIN:
	MOVLW	'D'
	CALL	SEND_BYTE
	MOVLW	'R'
	CALL	SEND_BYTE
	MOVLW	'O'
	CALL	SEND_BYTE
	MOVLW	' '
	CALL	SEND_BYTE
	
	MOVLW	'T'
	CALL	SEND_BYTE
	MOVLW	'e'
	CALL	SEND_BYTE
	MOVLW	's'
	CALL	SEND_BYTE
	MOVLW	't'
	CALL	SEND_BYTE
	MOVLW	' '
	CALL	SEND_BYTE
	MOVLW	'1'
	CALL	SEND_BYTE
	
	CALL	SEND_CRLF

LOOP:
	CLRF	PORTB
ACQ_DRO0:
	; reset tmr1 for timeout
	CLRF	TMR1H
	CLRF	TMR1L
	BCF	PIR1, TMR1IF
ACQ_DRO0_0:
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO0_timeout
	
	BTFSC	pin_DRO0_CLOCK	; wait for clock low
	GOTO	ACQ_DRO0_0
	CLRF	TMR0		; clear tmr0
	BCF	INTCON, TMR0IF	; clear flag
ACQ_DRO0_1:
	BSF	PORTB, 0
	BTFSC	pin_DRO0_CLOCK	; check if clock high
	GOTO	ACQ_DRO0_0	; reacquire if under 1ms of idle
	
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO0_timeout
	
	BTFSS	INTCON, TMR0IF
	GOTO	ACQ_DRO0_1

	BSF	PORTB, 1
	CLRF	data_0
	CLRF	data_1
	CLRF	data_2
	STR	23, read_loop
	
READ_DRO0_loop1:
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO0_timeout
	
	BTFSS	pin_DRO0_CLOCK		;wait for clock up
	GOTO	READ_DRO0_loop1

READ_DRO0_loop2:
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO0_timeout
	
	BTFSC	pin_DRO0_CLOCK		; wait for clock down
	GOTO	READ_DRO0_loop2
	
	BTFSC	pin_DRO0_DATA		; bits are inverted in input level transistor
	GOTO	READ_DRO0_skip
	
	BSetc	data_0, read_loop
READ_DRO0_skip:
	MOVLW	0x08
	XORWF	PORTB, F
	
	DECF	read_loop, F
	INCF	read_loop, W
	BTFSS	STATUS, Z
	GOTO	READ_DRO0_loop1
	
	MOVLW	'0'
	CALL	SEND_BYTE
	MOVLW	' '
	CALL	SEND_BYTE
	CALL	SEND_DATA
	


ACQ_DRO1:
	; reset TMR1 for timeout
	CLRF	TMR1H
	CLRF	TMR1L
	BCF	PIR1, TMR1IF
ACQ_DRO1_0:
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO1_timeout
	
	BTFSC	pin_DRO1_CLOCK	; wait for clock low
	GOTO	ACQ_DRO1_0
	CLRF	TMR0		; clear tmr0
	BCF	INTCON, TMR0IF	; clear flag
ACQ_DRO1_1:
	BSF	PORTB, 5
	BTFSC	pin_DRO1_CLOCK	; check if clock high
	GOTO	ACQ_DRO1_0	; reacquire if under 1ms of idle
	
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO1_timeout
	
	BTFSS	INTCON, TMR0IF
	GOTO	ACQ_DRO1_1
	
	BSF	PORTB, 6
	CLRF	data_0
	CLRF	data_1
	CLRF	data_2
	STR	23, read_loop
	
READ_DRO1_loop1:
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO1_timeout
	
	BTFSS	pin_DRO1_CLOCK		;wait for clock up
	GOTO	READ_DRO1_loop1


READ_DRO1_loop2:
	BTFSC	PIR1, TMR1IF	; check for timeout with TMR1
	GOTO	DRO1_timeout
	
	BTFSC	pin_DRO1_CLOCK		; wait for clock down
	GOTO	READ_DRO1_loop2
	
	BTFSC	pin_DRO1_DATA		; bits are inverted in input level transistor
	GOTO	READ_DRO1_skip
	
	BSetc	data_0, read_loop
READ_DRO1_skip:
	MOVLW	64
	XORWF	PORTB, F
	
	DECF	read_loop, F
	INCF	read_loop, W
	BTFSS	STATUS, Z
	GOTO	READ_DRO1_loop1
	
	MOVLW	'1'
	CALL	SEND_BYTE
	MOVLW	' '
	CALL	SEND_BYTE
	CALL	SEND_DATA
		

	GOTO	LOOP

DRO0_timeout:
	BSF	PORTA, 4
	GOTO	ACQ_DRO1
DRO1_timeout:
	BSF	PORTA, 4	
	GOTO	LOOP

; routines	


SEND_DATA:	
	MOVLW	HIGH(table_nibbleHex)
	MOVWF	PCLATH
	
	SWAPF	data_0, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	CALL	SEND_BYTE
	
	MOVF	data_0, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	CALL	SEND_BYTE
	
	SWAPF	data_1, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	CALL	SEND_BYTE
	
	MOVF	data_1, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	CALL	SEND_BYTE
	
	SWAPF	data_2, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	CALL	SEND_BYTE
	
	MOVF	data_2, W
	ANDLW	0x0F
	CALL	table_nibbleHex
	CALL	SEND_BYTE

	CALL	SEND_CRLF
	RETURN
	
; UART routines
SEND_BYTE:	; send byte to UART, blocking
	BTFSS	PIR1, TXIF
	GOTO	SEND_BYTE
	MOVWF	TXREG
	RETURN

SEND_CRLF:
	BTFSS	PIR1, TXIF
	GOTO	SEND_CRLF
	MOVLW	0x0D
	MOVWF	TXREG
SEND_CRLF_0:
	BTFSS	PIR1, TXIF
	GOTO	SEND_CRLF_0
	MOVLW	0x0A
	MOVWF	TXREG
	RETURN
	
; 	Int to Hex nibble char table
	PC0x0100SKIP
table_nibbleHex:
	ADDWF	PCL, F
	dt	"0123456789ABCDEF"
	
;#############################################################################
;	Delay routines	for 8MHz
;	 at 8MHz intrc, 2Mips, 0.5us per instruction cycle
;#############################################################################
; 2 000 000 cycles
 
WAIT_1s:				; (2) call
	MOVLW	10			; (1) 10x 200 000
	MOVWF	WAIT_loopCounter1	; (1)
; 4 overhead
WAIT_1s_loop1:
	MOVLW	200			; (1) for 100 ms
	MOVWF	WAIT_loopCounter2	; (1)
; loop 1 overhead 5 * 200
WAIT_1s_loop2:			; 0.5ms / loop1
	MOVLW	250 - 2			; (1) 250 loops of 4 cycles (minus 2 loop for setup and next loop)
	MOVWF	WAIT_loopCounter3	; (1)
	GOTO 	$ + 1			; (2)	
; loop 2 overhead 7 * 248
WAIT_1s_loop3:			; 4 cycles per loop (2us / loop2)
	NOP				; (1)
	DECFSZ	WAIT_loopCounter3, F	; (1)
	GOTO	WAIT_1s_loop3		; (2)
	
	GOTO 	$ + 1			; (2)
	
	DECFSZ	WAIT_loopCounter2, F	; (1)
	GOTO	WAIT_1s_loop2		; (2)

	DECFSZ	WAIT_loopCounter1, F	; (1)
	GOTO	WAIT_1s_loop1		; (2)
	RETURN				; (2)
; 2 return


WAIT_50ms:;100006 cycles or 50.003 ms; (2) call
	MOVLW	100			; (1)
	MOVWF	WAIT_loopCounter1	; (1)
WAIT_50ms_loop1:			; 0.5ms / loop1
	MOVLW	199			; (1) 250 loops of 4 cycles (minus 2 loop for setup and next loop)
	MOVWF	WAIT_loopCounter2	; (1)
WAIT_50ms_loop2:			;  5 cycles per loop (2us / loop2)
	GOTO 	$ + 1			; (2)	
	DECFSZ	WAIT_loopCounter2, F	; (1)
	GOTO	WAIT_50ms_loop2	; (2)
	DECFSZ	WAIT_loopCounter1, F	; (1)
	GOTO	WAIT_50ms_loop1	; (2)
	RETURN				; (2)

WAIT_50us:				; (2) call is 2 cycle
	MOVLW	23			; (1) 100 instruction for 50 us, 1 == 10 cycles = 5us, 2 is 14, 3 is 18, 4 is 22
	MOVWF	WAIT_loopCounter1	; (1)
WAIT_50us_loop:
	NOP				; (1)
	DECFSZ	WAIT_loopCounter1, F	; (1)
	GOTO	WAIT_50us_loop		; (2)
	GOTO	$ + 1			; (2)
	RETURN				; (2)
	
WAIT_5us:				; (2) call is 2 cycle
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	GOTO	$ + 1			; (2)
	RETURN				; (2) return is 2 cycle

;#############################################################################
;	End Declaration
;#############################################################################

	END

	
	
	
	
	
	
	
	
	
	
	
