;#############################################################################
;
;	4x4 keypad scanner and display
;	scan trough 74LS164
;	LCD display serial to 4 bit parallel v2
;	
;#############################################################################
; 74LS164 as https://hackaday.com/2015/04/15/simple-keypad-scanning-with-spi-and-some-hardware/

	LIST	p=16F88			; processor model
#INCLUDE	<P16F88.INC>		; processor specific variable definitions
#INCLUDE	<PIC16F88_Macro.asm>	; base macro for banks, context, branchs
#INCLUDE	<PIC16F88_MacroExt.asm> ; 16/24/32 bit instructions extensions
;#INCLUDE	"PIC16F88_Timing8MHz.asm"

;#############################################################################
;	Configuration
;#############################################################################

	__CONFIG	_CONFIG1, 	_CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & _WDT_OFF & _INTRC_IO
	__CONFIG	_CONFIG2, 	_IESO_OFF & _FCMEN_OFF

;#############################################################################
;	Pinout
;#############################################################################

; PIC16F88:
; pin  1 IOA PORTA2	O LCD Clock
; pin  2 IOA PORTA3	O LCD E
; pin  3 IOA PORTA4	O LCD Data
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O Scan Clock
; pin  7 IO_ PORTB1	O Scan Output
; pin  8 IOR PORTB2	I Scan Input
; pin  9 IO_ PORTB3	

; pin 10 IO_ PORTB4	
; pin 11 IOT PORTB5
; pin 12 IOA PORTB6	I ICSP PGC
; pin 13 IOA PORTB7	I ICSP PGD
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O ISR Status Bit
; pin 16 I_X PORTA7	
; pin 17 IOA PORTA0	
; pin 18 IOA PORTA1	


; V+ (square pad)
; Clock
; E
; Data
; GND

;#DEFINE 		PORTA, 0
;#DEFINE 		PORTA, 1
#DEFINE LCD_Clock		PORTA, 2
#DEFINE LCD_E			PORTA, 3

#DEFINE LCD_Data		PORTA, 4
;#DEFINE MCLR			PORTA, 5
#DEFINE StatusBit_ISR		PORTA, 6
;#DEFINE		PORTA, 7

#DEFINE Scan_Clock		PORTB, 0
#DEFINE Scan_Output		PORTB, 1
#DEFINE Scan_Input		PORTB, 2
;#DEFINE 		PORTB, 3

;#DEFINE 		PORTB, 4
;#DEFINE 		PORTB, 5
;#DEFINE PGC			PORTB, 6
;#DEFINE PGD			PORTB, 7


; RS set to 0
#DEFINE _LCD_CMD_Clear	b'00000001'
#DEFINE _LCD_CMD_Home		b'00000010'

#DEFINE _LCD_CMD_EntryMode	b'00000100'
#DEFINE _LCD_CMD_EntryModeINC		b'00000010'
#DEFINE _LCD_CMD_EntryModeDEC		b'00000000'
#DEFINE _LCD_CMD_EntryModeShift	b'00000001'
#DEFINE _LCD_CMD_EntryModeNoShift	b'00000000'

#DEFINE _LCD_CMD_Display	b'00001000'
#DEFINE _LCD_CMD_DisplayBlink	 	b'00000001'
#DEFINE _LCD_CMD_DisplayNoBlink 	b'00000000'
#DEFINE _LCD_CMD_DisplayCursor	b'00000010'
#DEFINE _LCD_CMD_DisplayNoCursor	b'00000000'
#DEFINE _LCD_CMD_DisplayOn	 	b'00000100'
#DEFINE _LCD_CMD_DisplayOff	 	b'00000000'

#DEFINE _LCD_CMD_Shift 	b'00010000'
#DEFINE _LCD_CMD_ShiftDisplay 	b'00001000'
#DEFINE _LCD_CMD_ShiftCursor	 	b'00000000'
#DEFINE _LCD_CMD_ShiftRight	 	b'00000100'
#DEFINE _LCD_CMD_ShiftLeft	 	b'00000000'

#DEFINE _LCD_CMD_System	b'00100000'
#DEFINE _LCD_CMD_System8bits		b'00010000'
#DEFINE _LCD_CMD_System4bits		b'00000000'
#DEFINE _LCD_CMD_System2lines		b'00001000'
#DEFINE _LCD_CMD_System1line		b'00000000'
#DEFINE _LCD_CMD_System5x10		b'00000100'
#DEFINE _LCD_CMD_System5x7		b'00000000'

#DEFINE _LCD_CMD_CGAddress	b'01000000' ; 6 last bits are character gernerator ram address to set
#DEFINE _LCD_CMD_DDAddress	b'10000000' ; 7 last bits are display ram address to set

#DEFINE _LCD_CMD_Line0 	b'10000000' 
#DEFINE _LCD_CMD_Line1	b'11000000' 

; RS set to 1
#DEFINE _LCD_CMD_Write	b'00000000'  ; 7 last bits are data to write
#DEFINE _LCD_CMD_Read		b'10000000'  ; 7 last bits are data


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

LCD_Char		EQU	0x23
Current_Char		EQU	0x24
LoopCount		EQU	0x25

d0			EQU	0x26
d1			EQU	0x27
d2			EQU	0x28
d3			EQU	0x29
d4			EQU	0x2A
d5			EQU	0x2B
d6			EQU	0x2C
d7			EQU	0x2D

bit_count		EQU	0x2E

scan_result		EQU	0x2F

scan_stream		EQU	0x30
keymap_line23		EQU	0x31

new_key			EQU	0x32
last_key		EQU	0x33

key_index		EQU	0x34
key_loop		EQU	0x35


;#############################################################################
;	Reset Vector - Main Entry Point
;#############################################################################

	ORG	0x0000
	GOTO	SETUP

;#############################################################################
;	Interrupt Vector - Interrupt Service Routine
;#############################################################################

	ORG	0x0004
	PUSH		;W, STATUS, PCLATH
	PUSHfsr		;FSR
	;PUSHscr	;SCRATCH
	BSF	StatusBit_ISR

	; select int
	BTFBS	PIR1, TMR1IF, ISR_T1
	
	GOTO	ISR_END 		; unkown interrupt

ISR_T1:
	STR	b'11000000', TMR1H ;61.025Hz	
	BCF	PIR1, TMR1IF
	GOTO	ISR_END
	
ISR_END:
	BCF	StatusBit_ISR
	;POPscr
	POPfsr
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
	
	BSF	Scan_Input	; input

	; init analog inputs
	CLRF	ANSEL		; all digital

	; init osc 8MHz
	BCF	OSCCON, SCS0
	BCF	OSCCON, SCS1
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
	BSF	PIE1, TMR1IE	; enable TMR1 interrupt
	
SETUP_OSC:
	BTFSS	OSCCON, IOFS
	GOTO	SETUP_OSC

	BANK0
	
	CLRF	TMR1L
	CLRF	TMR1H
	BCF	T1CON, T1CKPS0	; no PS
	BCF	T1CON, T1CKPS1	;
	BCF	T1CON, TMR1CS	; timer1 clock is FOSC/4
	BSF	T1CON, TMR1ON	; timer1 ON
	
	CLRF	PORTA
	CLRF	PORTB
	
	BCF	StatusBit_ISR

; enable interrupts
	BSF	INTCON, PEIE ; enable peripheral int
	BSF	INTCON, GIE  ; enable global int
	

;#############################################################################
;	LCD Initialization
;#############################################################################

	MOVLW	high (Wait_50ms)
	MOVWF	PCLATH	
	CALL	Wait_50ms
	
	MOVLW	(_LCD_CMD_System | _LCD_CMD_System4bits)
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	CALL	Wait_50ms
	
	MOVLW	(_LCD_CMD_System | _LCD_CMD_System4bits)
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	CALL	Wait_50ms
	
	MOVLW	(_LCD_CMD_System | _LCD_CMD_System4bits)
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	CALL	Wait_50ms
	
	MOVLW	(_LCD_CMD_System | _LCD_CMD_System4bits | _LCD_CMD_System2lines | _LCD_CMD_System5x10)
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	CALL	Wait_50ms
	
	MOVLW	(_LCD_CMD_Display | _LCD_CMD_DisplayOn)	; display on
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	CALL	Wait_50ms
	
	MOVLW	_LCD_CMD_Clear					; display clear
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	CALL	Wait_50ms
	
	MOVLW	(_LCD_CMD_EntryMode | _LCD_CMD_EntryModeINC | _LCD_CMD_EntryModeNoShift)
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	CALL	Wait_50ms
	
; init 74LS164 reader to 0

	BCF	Scan_Output
	
	MOVLW	0x08
	MOVWF	LoopCount
ResetClockLoop:
	BCF	Scan_Clock
	CALL	WAIT_50us
	BSF	Scan_Clock
	CALL	WAIT_50us
	DECFSZ	LoopCount, F
	GOTO	ResetClockLoop
	
	
;#############################################################################
;	Main Loop
;#############################################################################

LOOP:
	MOVLW	'0'
	MOVWF	d0
	MOVWF	d1
	MOVWF	d2
	MOVWF	d3
	MOVWF	d4
	MOVWF	d5
	MOVWF	d6
	MOVWF	d7
	

	MOVLW	' '
	MOVWF	last_key
	MOVWF	new_key
	
LOOP_start:
	MOVLW	high (LCD_SendCommand)
	MOVWF	PCLATH	

	MOVLW	_LCD_CMD_Line1
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	
	; scan keypad
	
	CLRF	scan_stream
	
	BSF	Scan_Output
	BCF	Scan_Clock
	CALL	WAIT_50us
	BSF	Scan_Clock
	CALL	WAIT_50us
	
	BTFSC	Scan_Input
	BSF	scan_stream, 0
	
	BCF	Scan_Output
	
	
	MOVLW	0x07
	MOVWF	LoopCount
ScanClockLoop:
	RLF	scan_stream, F

	BCF	Scan_Clock
	CALL	WAIT_50us
	BSF	Scan_Clock
	CALL	WAIT_50us
	
	BTFSC	Scan_Input
	BSF	scan_stream, 0
		
	DECFSZ	LoopCount, F
	GOTO	ScanClockLoop
	
	; display bit stream
	
	MOVLW	'0'
	BTFSC	scan_stream, 7
	MOVLW	'1'
	MOVWF	LCD_Char	
	CALL	LCD_SendChar
	
	MOVLW	'0'
	BTFSC	scan_stream, 6
	MOVLW	'1'
	MOVWF	LCD_Char	
	CALL	LCD_SendChar
	
	MOVLW	'0'
	BTFSC	scan_stream, 5
	MOVLW	'1'
	MOVWF	LCD_Char	
	CALL	LCD_SendChar
	
	MOVLW	'0'
	BTFSC	scan_stream, 4
	MOVLW	'1'
	MOVWF	LCD_Char	
	CALL	LCD_SendChar
	
	
	
	MOVLW	'0'
	BTFSC	scan_stream, 3
	MOVLW	'1'
	MOVWF	LCD_Char	
	CALL	LCD_SendChar
	
	MOVLW	'0'
	BTFSC	scan_stream, 2
	MOVLW	'1'
	MOVWF	LCD_Char	
	CALL	LCD_SendChar
	
	MOVLW	'0'
	BTFSC	scan_stream, 1
	MOVLW	'1'
	MOVWF	LCD_Char	
	CALL	LCD_SendChar
	
	MOVLW	'0'
	BTFSC	scan_stream, 0
	MOVLW	'1'
	MOVWF	LCD_Char	
	CALL	LCD_SendChar
	
	
	; check data valid
	CLRF	bit_count
	
	MOVF	scan_stream, W
	MOVWF	scan_result
	
	MOVLW	0x08
	MOVWF	LoopCount
BitCountLoop:
	BCF	STATUS, C
	RRF	scan_result, F
	BTFSC	STATUS, C
	INCF	bit_count, F
	DECFSZ	LoopCount, F
	GOTO	BitCountLoop
	
	MOVLW	" "
	MOVWF	LCD_Char
	CALL	LCD_SendChar	
	
	MOVLW	"X"
	MOVWF	LCD_Char
	
	MOVF	bit_count, W
	SUBLW	0x02
	BTFSS	STATUS, Z
	GOTO	DispChar
	; calculate char
	
	CLRF	scan_result	
	; 0001 0001 0
	; 0001 0010 1
	; 0001 0100 2
	; 0001 1000 3
	
	; 0010 0001 4
	; 0010 0010 5 
	; 0010 0100 6
	; 0010 1000 7
	CLRW
	BTFSC	scan_stream, 1
	MOVLW	1
	BTFSC	scan_stream, 2
	MOVLW	2
	BTFSC	scan_stream, 3
	MOVLW	3

	ADDWF	scan_result, F
	
	CLRW
	BTFSC	scan_stream, 5
	MOVLW	4
	BTFSC	scan_stream, 6
	MOVLW	8
	BTFSC	scan_stream, 7
	MOVLW	12
	
	ADDWF	scan_result, F
	
	MOVLW	HIGH (table_nibbleHex)
	MOVWF	PCLATH
	
	MOVF	scan_result, W
	CALL	table_nibbleHex
	MOVWF	LCD_Char
	
DispChar:
	MOVLW	HIGH (LCD_SendChar)
	MOVWF	PCLATH
	CALL	LCD_SendChar
	

	
	
;	SWAPF	scan_stream, W
;	ANDWF	0x0F, W
;	CALL	table_nibbleHex
;	MOVWF	LCD_Char
;	CALL	LCD_SendChar

LOOP_count:
	MOVLW	_LCD_CMD_Line0
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	
	MOVF	d7, W
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVF	d6, W
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVF	d5, W
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVF	d4, W
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVF	d3, W
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVF	d2, W
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVF	d1, W
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVF	d0, W
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	CALL	Wait_50ms;
	
	INCF	d0, F
	MOVLW	':'
	SUBWF	d0, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start	
	MOVLW	'0'
	MOVWF	d0
	
	INCF	d1, F
	MOVLW	':'
	SUBWF	d1, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start	
	MOVLW	'0'
	MOVWF	d1
	
	INCF	d2, F
	MOVLW	':'
	SUBWF	d2, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start	
	MOVLW	'0'
	MOVWF	d2
	
	INCF	d3, F
	MOVLW	':'
	SUBWF	d3, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start	
	MOVLW	'0'
	MOVWF	d3
	
	INCF	d4, F
	MOVLW	':'
	SUBWF	d4, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start	
	MOVLW	'0'
	MOVWF	d4
	
	INCF	d5, F
	MOVLW	':'
	SUBWF	d5, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start
	MOVLW	'0'
	MOVWF	d5
	
	INCF	d6, F
	MOVLW	':'
	SUBWF	d6, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start	
	MOVLW	'0'
	MOVWF	d6
	
	INCF	d7, F
	MOVLW	':'
	SUBWF	d7, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start	
	MOVLW	'0'
	MOVWF	d7
	
	GOTO	LOOP_start

	
;#############################################################################
;	End of main loop
;#############################################################################


;#############################################################################
;	Subroutines
;#############################################################################






	
; RS
; db7
; db6
; db5
; db4
; strobe E

LCD_SendCommand:

	; high nibble
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data	; RS 0
	BSF	LCD_Clock	; clock up
	
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data
	BTFSC	LCD_Char, 7	; db7 is bit 7
	BSF	LCD_Data
	BSF	LCD_Clock	; clock up
		
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data
	BTFSC	LCD_Char, 6	; db6 is bit 6
	BSF	LCD_Data
	BSF	LCD_Clock	; clock up
	
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data
	BTFSC	LCD_Char, 5	; db5 is bit 5
	BSF	LCD_Data
	BSF	LCD_Clock	; clock up
	
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data
	BTFSC	LCD_Char, 4	; db5 is bit 4
	BSF	LCD_Data
	BSF	LCD_Clock	; clock up
		
	BCF	LCD_Clock	; clock down
	BSF	LCD_E 		; strobe E min 220ns
	BCF	LCD_E
	
	; low nibble
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data	; RS 0
	BSF	LCD_Clock	; clock up
	
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data
	BTFSC	LCD_Char, 3	; db7 is bit 3
	BSF	LCD_Data
	BSF	LCD_Clock	; clock up
		
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data
	BTFSC	LCD_Char, 2	; db6 is bit 2
	BSF	LCD_Data
	BSF	LCD_Clock	; clock up
	
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data
	BTFSC	LCD_Char, 1	; db5 is bit 1
	BSF	LCD_Data
	BSF	LCD_Clock	; clock up
	
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data
	BTFSC	LCD_Char, 0	; db5 is bit 0
	BSF	LCD_Data
	BSF	LCD_Clock	; clock up
		
	BCF	LCD_Clock	; clock down
	BSF	LCD_E 		; strobe E min 220ns
	BCF	LCD_E
	
	CALL	Wait_50us
	
	RETURN	
	

LCD_SendChar:
	; high nibble
	BCF	LCD_Clock	; clock down
	BSF	LCD_Data	; RS 1
	BSF	LCD_Clock	; clock up
	
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data	; db7 is 0 to write data
	BSF	LCD_Clock	; clock up
		
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data
	BTFSC	LCD_Char, 6	; db6 is bit 6
	BSF	LCD_Data
	BSF	LCD_Clock	; clock up
	
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data
	BTFSC	LCD_Char, 5	; db5 is bit 5
	BSF	LCD_Data
	BSF	LCD_Clock	; clock up
	
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data
	BTFSC	LCD_Char, 4	; db5 is bit 4
	BSF	LCD_Data
	BSF	LCD_Clock	; clock up
		
	BCF	LCD_Clock	; clock down
	BSF	LCD_E 		; strobe E min 220ns
	BCF	LCD_E
	
	; low nibble
	BCF	LCD_Clock	; clock down
	BSF	LCD_Data	; RS 0
	BSF	LCD_Clock	; clock up
	
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data
	BTFSC	LCD_Char, 3	; db7 is bit 3
	BSF	LCD_Data
	BSF	LCD_Clock	; clock up
		
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data
	BTFSC	LCD_Char, 2	; db6 is bit 2
	BSF	LCD_Data
	BSF	LCD_Clock	; clock up
	
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data
	BTFSC	LCD_Char, 1	; db5 is bit 1
	BSF	LCD_Data
	BSF	LCD_Clock	; clock up
	
	BCF	LCD_Clock	; clock down
	BCF	LCD_Data
	BTFSC	LCD_Char, 0	; db5 is bit 0
	BSF	LCD_Data
	BSF	LCD_Clock	; clock up
		
	BCF	LCD_Clock	; clock down
	BSF	LCD_E 		; strobe E min 220ns
	BCF	LCD_E
	
	CALL	Wait_50us
	
	RETURN
;#############################################################################
;	Tables
;#############################################################################

	PC0x0100SKIP	; skip to next 256 byte boundary in program memory
	
; 	Int to Hex nibble char table
table_nibbleHex:
	ADDWF	PCL, F
	dt	"0123456789ABCDEF"

table_keyPad:
	ADDWF	PCL, F
	dt	"147*2580369#ABCD"
;#############################################################################
;	PC 0x800 (1k) boundary
;#############################################################################

	;PC0x0800SKIP

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
