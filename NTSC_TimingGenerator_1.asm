;#############################################################################
;
;	NTSC sync generator
;
;#############################################################################
;
;	Version 1
; per AY-3-8500 coleco 
; 160 PPU wide 64 us scanline 0.4us per pixel
;	 blank 27
		; front porch 4
		; sync 11
		; back porch 12
;	 data 133
;
; at 20 MHz, 5MINS/sec, 0.2us per instructions, 2 instructions per PPU
;
; start of field
; 42 lines
; data 190 lines
; end of field 25 lines
; vertical sync 4 lines (256us)
;
; 13.5us before start of line data, 36.5us of data, 8 us after, 6 sync pulse;
;
; end of H data
; blanking is 10.7us - 11.1us
		; front porch 1.4us - 1.6us
		; pulse 4.6-4.8us
		; backporch / burst 0.6 + 2.5 + 1.6 = 4.7us
;
; todo 5(+1)x8 font generator 

;#############################################################################

	LIST	p=16F88			; processor model
#INCLUDE	<P16F88.INC>		; processor specific variable definitions
#INCLUDE	<PIC16F88_Macro.asm>	; base macro for banks, context, branchs
;#INCLUDE	<PIC16F88_MacroExt.asm> ; 16/24/32 bit instructions extensions
	ERRORLEVEL -302		; suppress "bank" warnings
;MPASMx /c- /e+ /m+ /pPIC16F88 /rDEC ..\PIC16F88\DRO_Lathe_1b.asm
	
;#############################################################################
;	Configuration
;#############################################################################

	__CONFIG	_CONFIG1, 	_CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & _WDT_OFF & _HS_OSC
	__CONFIG	_CONFIG2, 	_IESO_OFF & _FCMEN_OFF

;#############################################################################
;	Pinout
;#############################################################################

; PIC16F88:
; pin  1 IOA PORTA2	O pin_SYNC
; pin  2 IOA PORTA3	O DRO0 DATA
; pin  3 IOA PORTA4	O
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O 
; pin  7 IO_ PORTB1	O 
; pin  8 IOR PORTB2	I UART RX
; pin  9 IO_ PORTB3	O

; pin 10 IO_ PORTB4	O 
; pin 11 IOT PORTB5	O UART TX
; pin 12 IOA PORTB6	I ICSP PGC
; pin 13 IOA PORTB7	I ICSP PGD
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O 
; pin 16 I_X PORTA7	O 
; pin 17 IOA PORTA0	O 
; pin 18 IOA PORTA1	O 



; #DEFINE pin_DRO1_CLOCK	PORTA, 0
; #DEFINE pin_DRO1_DATA		PORTA, 1
 #DEFINE pin_SYNC		PORTA, 2
 #DEFINE pin_DATA		PORTA, 3

; #DEFINE pin_KEYPAD_CLOCK	PORTA, 4
;#DEFINE MCLR			PORTA, 5
; #DEFINE pin_KEYPAD_OUTPUT	PORTA, 6
; #DEFINE pin_KEYPAD_INPUT	PORTA, 7

; #DEFINE pin_Disp_CLOCK	PORTB, 0
; #DEFINE pin_Disp0_DATA	PORTB, 1
;#DEFINE UART RX		PORTB, 2
; #DEFINE pin_Disp1_DATA	PORTB, 3

; #DEFINE pin_SWITCH		PORTB, 4
; #DEFINE pin_UART_TX		PORTB, 5
; #DEFINE pin_debug2		PORTB, 6 ; PGC
; #DEFINE pin_debug1		PORTB, 7 ; PGD


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
V_count			EQU	0x22
H_count			EQU	0x23

; raw DRO data, 2's complement
dro0_0			EQU	0x24
dro0_1			EQU	0x25
dro0_2			EQU	0x26

dro1_0			EQU	0x27
dro1_1			EQU	0x28
dro1_2			EQU	0x29

dro2_0			EQU	0x2A
dro2_1			EQU	0x2B
dro2_2			EQU	0x2C

; keypad_key		EQU	0x2D
; keypad_last		EQU	0x2E
; bit_keyUp		EQU	6
; bit_keyRepeat		EQU	7

; keypad_status		EQU	0x2F
; bit_keyEntry0		EQU	0	; entering dro0 actual
; bit_keyEntry1		EQU	1	; entering dro1 actual
; bit_keyEntry2		EQU	2	; entering dro2 actual
; bit_keyEntry		EQU	3	; entering actual
; bit_keySign		EQU	6	; entering sign
; mask_keySign		EQU	0x40
; bit_keySwitchLast	EQU	7	; unit switch last state

; current entry packed BCD with sign bit in entry 
; dro_offset_0		EQU	0x30
; dro_offset_1		EQU	0x31
; dro_offset_2		EQU	0x32

; offset for DRO data, 2's complement
; dro0_offset_0		EQU	0x33
; dro0_offset_1		EQU	0x34
; dro0_offset_2		EQU	0x35

; dro1_offset_0		EQU	0x36
; dro1_offset_1		EQU	0x37
; dro1_offset_2		EQU	0x38

; dro2_offset_0		EQU	0x39
; dro2_offset_1		EQU	0x3A
; dro2_offset_2		EQU	0x3B

; current data
; in 100th of MM, sign in status bit
; data_f			EQU	0x3C
; data_0			EQU	0x3D
; data_1			EQU	0x3E
; data_2			EQU	0x3F
; data_3			EQU	0x40
; bit_dataSign		EQU	4
; mask_dataSign		EQU	0x10

; accum_0			EQU	0x41
; accum_1			EQU	0x42
; accum_2			EQU	0x43
; accum_3			EQU	0x44

;			EQU	0x45
;			EQU	0x46
;			EQU	0x47

; data_status		EQU	0x48
; bit_statusDRO0Sign	EQU	0
; bit_statusDRO1Sign	EQU	1
; bit_statusDRO2Sign	EQU	2
; ;bit_status		EQU	3
; bit_statusSign		EQU	4
; mask_statusSign	EQU	0x10 
; bit_statusUnit		EQU	5 ; 0:mm, 1:in
; mask_statusUnit	EQU	0x20 
; bit_statusSuppressD3	EQU	6
; bit_statusSuppressD4	EQU	7

;			EQU	0x49

; packed BCD of data for display
; data_BCD0		EQU	0x4A
; data_BCD1		EQU	0x4B
; data_BCD2		EQU	0x4C
; data_BCD3		EQU	0x4D; could be ignored
; max display length -99.999 inches
; max display length -999.99 mm (1 m)
; max of 20 bit 10485.75

; mask_DRO_Clock		EQU	0x4E
; mask_DRO_Data		EQU	0x4F

; disp_currentSetMask	EQU	0x50
; disp_currentClearMask	EQU	0x51
; disp_buffer		EQU	0x52
; PORTB_buffer		EQU	0x53

;			EQU	0x54
;			EQU	0x55
;			EQU	0x56
;			EQU	0x57
;			EQU	0x58
;			EQU	0x59
;			EQU	0x5A
;			EQU	0x5B
;			EQU	0x5C
;			EQU	0x5D
;			EQU	0x5E
;			EQU	0x5F

; CFG			EQU	0x60	; axix X2 and reverse
; bit_CFGdia0		EQU	0
; bit_CFGdia1		EQU	1
; bit_CFGdia2		EQU	2
; bit_CFGdia		EQU	3 ; current for selected dro
; bit_CFGreverse0	EQU	4
; bit_CFGreverse1	EQU	5
; bit_CFGreverse2	EQU	6
; bit_CFGreverse		EQU	7 ; current for selected dro
; CFG_1			EQU	0x61	; display brightness

;			EQU	0x62
;			EQU	0x63
;			EQU	0x64
;			EQU	0x65
;			EQU	0x66
;			EQU	0x67
;			EQU	0x68
;			EQU	0x69
;			EQU	0x6A
; temp_f			EQU	0x6B
; temp_0			EQU	0x6C
; temp_1			EQU	0x6D
; temp_2			EQU	0x6E
;			EQU	0x6F		


;#############################################################################
;
;	Macro definitions
;
;#############################################################################


;#############################################################################
;	Reset Vector - Main Entry Point
;#############################################################################

	ORG	0x0000
RESET:
	GOTO	SETUP

;#############################################################################
;	Interrupt Vector - Interrupt Service Routine
;#############################################################################

	ORG	0x0004
ISR:
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
	
	; init osc 20MHz ext
	BCF	OSCCON, SCS0 ;per config
	BCF	OSCCON, SCS1
	; BSF	OSCCON, IRCF0
	; BSF	OSCCON, IRCF1
	; BSF	OSCCON, IRCF2
	
; SETUP_OSC:
	; BTFSS	OSCCON, IOFS
	; GOTO	SETUP_OSC
	
	; UART at 9600, 8 bits, async
	;BSF	TXSTA, CSRC	; not used in async - set as clock source master
	; BCF 	TXSTA, TX9	; 8 bit tx
	; BSF	TXSTA, TXEN	; enable tx
	; BCF	TXSTA, SYNC	; async
	
	; set 9600 baud rate
	; BSF 	TXSTA, BRGH	; high speed baud rate generator	
	; MOVLW	51		; 9600 bauds
	; MOVWF	SPBRG
	
	; timer 0
	; BCF	OPTION_REG, T0CS ; on instruction clock
	; BCF	OPTION_REG, PSA ; pre scaler assigned to tmr0
	; BCF	OPTION_REG, PS2 ; 0
	; BSF	OPTION_REG, PS1 ; 1
	; BCF	OPTION_REG, PS0 ; 0 for 1:8 tmr0 ps
	; ; tmr0 overlfow every 8*256 instructions, or 2048 instructions / 1.024ms

	; BCF	PIE1, TMR1IE	; TMR1 interrupt
	
	BANK0
	
	; ports
	CLRF	PORTA
	CLRF	PORTB	

	; timer1
	; CLRF	TMR1L
	; CLRF	TMR1H
	; BCF	T1CON, T1CKPS0	; 0
	; BSF	T1CON, T1CKPS1	; 1
	; ; pre scaler is 1:4, overlfow of 65536 instructions cycles is 131ms
	; BCF	T1CON, TMR1CS	; timer1 clock is FOSC/4
	; BSF	T1CON, TMR1ON	; timer1 ON
	
	; UART
	; BSF	RCSTA, SPEN	; serial port enabled

; enable interrupts
	; BCF	INTCON, PEIE ; enable peripheral int
	; BCF	INTCON, TMR0IF; clear flag
	; BCF	INTCON, TMR0IE; enable tmr0 interrupt
	; CLRF	TMR0; clear tmr0

	BCF	INTCON, GIE
	
;#############################################################################
;	Program start 
;#############################################################################

MAIN:
	BSF	pin_SYNC
	BCF	pin_DATA

LOOP:

	MOVLW	26
	MOVWF	V_count
header:
	CALL	HORZ_void
	DECFSZ	V_count, F
	GOTO	header
	
	
	CALL	HORZ_fill ;28
	
	MOVLW	218
	MOVWF	V_count
sides:	
	CALL	HORZ_sides
	DECFSZ	V_count, F
	GOTO	sides
	
	CALL	HORZ_fill
	
	MOVLW	262 - 4 - 1 - 218 - 1 - 26; todo try more lines
	MOVWF	V_count
footer:	
	CALL	HORZ_void
	DECFSZ	V_count, F
	GOTO	footer
	

	CALL	HORZ_Vsync
	CALL	HORZ_Vsync	
	CALL	HORZ_Vsync
	CALL	HORZ_Vsync ;4
	
	; total 262 lines
	GOTO	LOOP



;#############################################################################
;	SUBROUTINES
;#############################################################################
; blanking is 10.7us - 11.1us total: 
;	 front porch 1.4us - 1.6us
;	 pulse 4.6-4.8us
;	 backporch / burst 0.6 + 2.5 + 1.6 = 4.7us
; total 63.5us, target 63 + overhead before call, so 315i
HORZ_void: ;2i,
	; make sure data is down, front porch
	BCF	pin_DATA ;1i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	; 7i = 1.4us + whatever before CALL, on the min
	
	BCF	pin_SYNC ;1i
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i (10i)
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i (10i)
	
	GOTO	$ + 1 		;2i
	BSF	pin_SYNC ;1i
	; 24i = 4.8us, on the max, can be adjusted with last 2i or 1i nop
	;total so far 31i
		
	MOVLW	70 ;1i
	MOVWF	H_count ;1i
	; 2i of setup, total 33i
	
HORZ_void_loop: ; 4i * H_count in loop, * 70 = 280
	NOP	; 1i * H_count
	DECFSZ	H_count, F ;1i * H_count	
	GOTO	HORZ_void_loop ;2i * H_count
	
	; 280 + 33 = 313
	RETURN	; 2i 
	; 315
	
	
	
HORZ_fill: ;2i
	; make sure data is down, front porch
	BCF	pin_DATA ;1i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	; 7i = 1.4us + whatever before CALL, on the min
	
	BCF	pin_SYNC ;1i
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i (10i)
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i (10i)
	
	GOTO	$ + 1 		;2i
	BSF	pin_SYNC ;1i
	; 24i = 4.8us, on the max, can be adjusted with last 2i or 1i nop
	;total so far 31i
	
	;4.7 back porch	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i (10i)
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i (10i)
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	; 24i, 4.4us
	; total 55i, 11us

	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	;8i
	;total 63
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	;8i
	;total 71i
	
	GOTO	$ + 1 	;2i
	BSF	pin_DATA ;1i 
	;74i
	
	MOVLW	56 ;1i
	MOVWF	H_count ;1i
	; 76i
	
HORZ_fill_loop1: ; 4i * H_count in loop, * 63 = 224
	NOP	; 1i * H_count
	DECFSZ	H_count, F ;1i * H_count
	GOTO	HORZ_fill_loop1 ;2i * H_count
	;300i 
	GOTO	$ + 1 	  ;2i
	;302i
	BCF	pin_DATA ;1i 	
	;303i
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	; block is 10
	;313
	RETURN	; 2i; 
	;total 315
	
	
	

HORZ_sides: ;2i
	; make sure data is down, front porch
	BCF	pin_DATA ;1i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	; 7i = 1.4us + whatever before CALL, on the min
	
	BCF	pin_SYNC ;1i
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i (10i)
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i (10i)
	
	GOTO	$ + 1 		;2i
	BSF	pin_SYNC ;1i
	; 24i = 4.8us, on the max, can be adjusted with last 2i or 1i nop
	;total so far 31i
	
	;4.7 back porch	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i (10i)
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i (10i)
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	; 24i, 4.4us
	; total 55i, 11us

	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	;8i
	;total 63
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	;8i
	;total 71i
	
	GOTO	$ + 1 	;2i
	BSF	pin_DATA ;1i 
	;74i
	BCF	pin_DATA ;1i 
	; 75i
	
	MOVLW	56 ;1i
	MOVWF	H_count ;1i
	; 77i
	
HORZ_sides_loop1: ; 4i * H_count in loop, * 57 = 224
	NOP	; 1i * H_count
	DECFSZ	H_count, F ;1i * H_count
	GOTO	HORZ_sides_loop1 ;2i * H_count
	
	;301
	BSF	pin_DATA ;1i 
	;302
	BCF	pin_DATA ;1i 	
	;303
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	; block is 10
	;313
	RETURN	; 2i; 
	;total 315
	
	

HORZ_Vsync: ; 0.2us per inst, call is 2i,
	; make sure data is down, front porch
	BCF	pin_DATA ;1i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	; 7i = 1.4us + whatever before CALL, on the min
	
	BCF	pin_SYNC ;1i
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i (10i)
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i (10i)
	
	GOTO	$ + 1 		;2i
	BSF	pin_SYNC ;1i
	; 24i = 4.8us, on the max, can be adjusted with last 2i or 1i nop
	;total so far 31i
	
	;4.7 back porch	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i (10i)
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i (10i)
	
	GOTO	$ + 1 		;2i
	GOTO	$ + 1 		;2i
	; 24i, 4.4us
	; total 55i, 11us

	BCF	pin_SYNC ;1i
	; 56i
	
	MOVLW	63 ;1i
	MOVWF	H_count ;1i
	; 58i
	
HORZ_Vsync_loop2: ; 4i * H_count in loop, * 63 = 252
	NOP	; 1i * H_count
	DECFSZ	H_count, F ;1i * H_count	
	GOTO	HORZ_Vsync_loop2 ;2i * H_count	
	;310
	
	GOTO	$ + 1 		;2i	
	BSF	pin_SYNC	;1i
	RETURN	; 2i
	;5
	;315


;#############################################################################
;	Data conversion and UART TX
;#############################################################################


;#############################################################################
;	Tables
;#############################################################################

	PC0x0100SKIP; align to next 256 byte boundary in program memory
	
; nibble to char
table_nibbleHex:
	ADDWF	PCL, F
	dt	"0123456789ABCDEF"

; byte to 7+1 segments
table_hexTo7seg:
	ADDWF	PCL, F
	RETLW	b'00111111';0
	RETLW	b'00000110';1
	RETLW	b'01011011';2
 	RETLW	b'01001111';3
	RETLW	b'01100110';4
 	RETLW	b'01101101';5
	RETLW	b'01111101';6
 	RETLW	b'00000111';7
 	RETLW	b'01111111';8
 	RETLW	b'01101111';9
 	RETLW	b'01110111';A
 	RETLW	b'01111100';b
 	RETLW	b'00111001';C
 	RETLW	b'01011110';d
 	RETLW	b'01111001';E
 	RETLW	b'01110001';F
	RETLW	b'10000000';.
	RETLW	b'01000000';-
	
;    aaa
;  f     b
;  f     b
;  f     b
;    ggg
;  e     c
;  e     c
;  e     c
;    ddd
;	  p

; bit 76543210
; seg pgfedcba 

;#############################################################################
;	PC High Byte Boundary skip
;#############################################################################

	ORG	0x0800
	
;#############################################################################
;	KEYPAD
;#############################################################################
	
;#############################################################################
;	Delay routines	for 8MHz
;	 at 8MHz intrc, 2Mips, 0.5us per instruction cycle
;#############################################################################
; 2 000 000 cycles

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
	CLRF	PCLATH			
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


;#############################################################################
;	End of memory trap, should never be reached
;#############################################################################

	ORG	0x0FFB
	BSF	PORTB, 4
	BSF	PCLATH, 3
	STALL
	
;#############################################################################
;	EEPROM default for testing
;#############################################################################
	
	;ORG	0x2100 ; the address of EEPROM is 0x2100 
; EEPROM data byte at 0x00 is config
; bit 0-3 x2 axis 0-3 (for radius to diameter direct reading)
; bit 4-7 is reverse axis direction
	;DE	b'00110001'
; EEPROM data byte at 0x00 is config
; bit 0-3 x2 axis 0-3 (for radius to diameter direct reading)
; bit 4-7 is reverse axis direction

; EEPROM data byte at 0x01 is config_1
; display brightness, 0-7
;	DE	3
	
;#############################################################################
;	End Declaration
;#############################################################################

	END

	
	
	
	
	
	
	
	
