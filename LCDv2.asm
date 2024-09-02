;#############################################################################
;	LCD display serial to 4 bit parallel v2
;	
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
; pin  1 IOA PORTA2	O LCD Clock
; pin  2 IOA PORTA3	O LCD E
; pin  3 IOA PORTA4	O LCD Data
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O
; pin  7 IO_ PORTB1	O 
; pin  8 IOR PORTB2	I RX from computer
; pin  9 IO_ PORTB3	O

; pin 10 IO_ PORTB4	O
; pin 11 IOT PORTB5	O TX to computer
; pin 12 IOA PORTB6	I ICSP PGC
; pin 13 IOA PORTB7	I ICSP PGD
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O ISR Status Bit
; pin 16 I_X PORTA7	O 
; pin 17 IOA PORTA0	O 
; pin 18 IOA PORTA1	O 


; V+ (square pad)
; Clock
; E
; Data
; GND


#DEFINE LCD_Clock		PORTA, 2
#DEFINE LCD_E			PORTA, 3
#DEFINE LCD_Data		PORTA, 4
#DEFINE StatusBit_ISR		PORTA, 6	

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
Char_Counter		EQU	0x25

d0			EQU	0x26
d1			EQU	0x27
d2			EQU	0x28
d3			EQU	0x29
d4			EQU	0x30
d5			EQU	0x31
d6			EQU	0x32
d7			EQU	0x33


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
	
	BTFBS	PIR1, TMR1IF, ISR_T1
	
	GOTO	ISR_END 		; unkown interrupt

ISR_T1:
	BCF	PIR1, TMR1IF
	STR	b'11110000', TMR1H

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
	BSF	StatusBit_ISR	; input
	CLRF	TRISB		; all outputs


	; init analog inputs
	CLRF	ANSEL		; all digital

	; init osc 8MHz
	BCF	OSCCON, SCS0
	BCF	OSCCON, SCS1
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
SETUP_OSC:
	BTFSS	OSCCON, IOFS
	GOTO	SETUP_OSC

	BANK0

	; at 8x prescaler, 8mhz crystal, 2mhz instruction clock, 3.8hz timer1 overflow
	CLRF	TMR1L
	CLRF	TMR1H
	BCF	T1CON, T1CKPS0	; 
	BCF	T1CON, T1CKPS1	;
	BCF	T1CON, TMR1CS	; timer clock is FOSC/4
	BSF	T1CON, TMR1ON	; timer ON

	CLRF	PORTA
	CLRF	PORTB
	
	BCF	StatusBit_ISR

; enable interrupts
	BSF	INTCON, PEIE ; peripheral int
	BSF	INTCON, GIE  ; global int
	

;#############################################################################
;	LCD Initialization
;#############################################################################

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
	
	GOTO 	LOOP
	
	MOVLW	'A'
	MOVWF	LCD_Char
	CALL	LCD_SendChar

	MOVLW	'B'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'C'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'D'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	

	MOVLW	'E'
	MOVWF	LCD_Char
	CALL	LCD_SendChar

	MOVLW	'F'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'G'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'H'
	MOVWF	LCD_Char
	CALL	LCD_SendChar	
	
	
	MOVLW	'I'
	MOVWF	LCD_Char
	CALL	LCD_SendChar

	MOVLW	'J'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'K'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'L'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	
	MOVLW	'M'
	MOVWF	LCD_Char
	CALL	LCD_SendChar

	MOVLW	'N'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'O'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'P'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	b'11000000'
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	
	MOVLW	'a'
	MOVWF	LCD_Char
	CALL	LCD_SendChar

	MOVLW	'b'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'c'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'd'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	

	MOVLW	'e'
	MOVWF	LCD_Char
	CALL	LCD_SendChar

	MOVLW	'f'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'g'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'h'
	MOVWF	LCD_Char
	CALL	LCD_SendChar	
	
	
	MOVLW	'i'
	MOVWF	LCD_Char
	CALL	LCD_SendChar

	MOVLW	'j'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'k'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'l'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	
	MOVLW	'm'
	MOVWF	LCD_Char
	CALL	LCD_SendChar

	MOVLW	'n'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'o'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	'p'
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
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
	
LOOP_start:
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
	
	;CALL	Wait_50ms;
	
	INCF	d0
	MOVLW	':'
	SUBWF	d0, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start	
	MOVLW	'0'
	MOVWF	d0
	
	INCF	d1
	MOVLW	':'
	SUBWF	d1, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start	
	MOVLW	'0'
	MOVWF	d1
	
	INCF	d2
	MOVLW	':'
	SUBWF	d2, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start	
	MOVLW	'0'
	MOVWF	d2
	
	INCF	d3
	MOVLW	':'
	SUBWF	d3, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start	
	MOVLW	'0'
	MOVWF	d3
	
	INCF	d4
	MOVLW	':'
	SUBWF	d4, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start	
	MOVLW	'0'
	MOVWF	d4
	
	INCF	d5
	MOVLW	':'
	SUBWF	d5, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start
	MOVLW	'0'
	MOVWF	d5
	
	INCF	d6
	MOVLW	':'
	SUBWF	d6, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start	
	MOVLW	'0'
	MOVWF	d6
	
	INCF	d7
	MOVLW	':'
	SUBWF	d7, W
	BTFSS	STATUS, Z
	GOTO	LOOP_start	
	MOVLW	'0'
	MOVWF	d7
	
	GOTO	LOOP_start

LOOPaaa:
	MOVLW	_LCD_CMD_Line0
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	
	MOVLW	0x3E
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	0x3C
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	0x3E
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	0x3C
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	CALL	Wait_50ms
	CALL	Wait_50ms
	CALL	Wait_50ms
	
	MOVLW	_LCD_CMD_Line0
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	
	MOVLW	0x3C
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	0x3E
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	0x3C
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	MOVLW	0x3E
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	CALL	Wait_50ms
	CALL	Wait_50ms
	CALL	Wait_50ms
	
	GOTO 	LOOP
	
	

LOOPaa:
	MOVLW	_LCD_CMD_Line0
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	
	MOVLW	16
	MOVWF	Char_Counter
	
	MOVLW	'0'
	MOVWF	Current_Char
	
LOOPa:
	MOVF	Current_Char, W
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	INCF	Current_Char, F
	DECFSZ	Char_Counter, F
	GOTO	LOOPa





	MOVLW	_LCD_CMD_Line1
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	
	MOVLW	16
	MOVWF	Char_Counter
	
	
LOOPb:
	MOVF	Current_Char, W
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	INCF	Current_Char, F
	DECFSZ	Char_Counter, F
	GOTO	LOOPb
	

	
	MOVLW	_LCD_CMD_Line0
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	
	MOVLW	16
	MOVWF	Char_Counter
	
	
LOOPc:
	MOVF	Current_Char, W
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	INCF	Current_Char, F
	DECFSZ	Char_Counter, F
	GOTO	LOOPc
	



	MOVLW	_LCD_CMD_Line1
	MOVWF	LCD_Char
	CALL	LCD_SendCommand
	
	MOVLW	16
	MOVWF	Char_Counter
	
	
LOOPd:
	MOVF	Current_Char, W
	MOVWF	LCD_Char
	CALL	LCD_SendChar
	
	INCF	Current_Char, F
	DECFSZ	Char_Counter, F
	GOTO	LOOPd

	CALL	Wait_50ms;
	CALL	Wait_50ms;
	
	GOTO	LOOP
	
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

	PC0x0100ALIGN	TABLE0	; set the label and align to next 256 byte boundary in program memory
TABLE0:
; 	Int to Hex nibble char table
NibbleHex:
	ADDWF	PCL, F
	dt	"0123456789ABCDEF"


;#############################################################################
;	PC 0x800 (1k) boundary
;#############################################################################

	;PC0x0800SKIP

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


WAIT_50ms:
	MOVLW	100			; (1) for 50 ms
	MOVWF	WAIT_loopCounter1	; (1)

WAIT_50ms_loop1:			; 0.5ms / loop1
	MOVLW	250 - 2			; (1) 250 loops of 4 cycles (minus 2 loop for setup and next loop)
	MOVWF	WAIT_loopCounter2	; (1)
	NOP				; (1)
	NOP				; (1)

WAIT_50ms_loop2:			; 4 cycles per loop (2us / loop2)
	NOP				; (1)
	DECFSZ	WAIT_loopCounter2, F	; (1)
	GOTO	WAIT_50ms_loop2	; (2)
	NOP				; (1)

	NOP				; (1)
	DECFSZ	WAIT_loopCounter1, F	; (1)
	GOTO	WAIT_50ms_loop1	; (2)

	RETURN
	
; at 8MHz intrc, 2Mips, 0.5us per instruction cycle
; call and setup is 4 cycles
; 23 loops is 23 * 4 = 92 cycles
; nop and return is 4 cycles
; total 100 cycles = 50us

WAIT_50us:				; (2) call is 2 cycle
	MOVLW	2			; (1) 100 instruction for 50 us, 1 == 10 cycles = 5us, 2 is 14, 3 is 18, 4 is 22
	MOVWF	WAIT_loopCounter1	; (1)
WAIT_50us_loop:
	NOP				; (1)
	DECFSZ	WAIT_loopCounter1, F	; (1)
	GOTO	WAIT_50ms_loop1	; (2)

	NOP				; (1)
	NOP				; (1)
	RETURN				; (2)

;#############################################################################
;	End Declaration
;#############################################################################

	END
