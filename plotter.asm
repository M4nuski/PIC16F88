;#############################################################################
;
;	ADC to POS thermal printer plotter
;
;#############################################################################
;
;	Version 1
; pool 10/s, display on printer

;#############################################################################

	LIST	p=16F88			; processor model
#INCLUDE	<P16F88.INC>		; processor specific variable definitions
#INCLUDE	<PIC16F88_Macro.asm>	; base macro for banks, context, branchs
;#INCLUDE	<PIC16F88_MacroExt.asm> ; 16/24/32 bit instructions extensions
	ERRORLEVEL -302		; suppress "bank" warnings
;MPASMx /c- /e+ /m+ /rDEC "$(FULL_CURRENT_PATH)"
;cmd.exe /k ""C:/Prog/PIC/MPASM 560/MPASMx" /c- /e=CON /q+ /m+ /x- /rDEC  "$(FULL_CURRENT_PATH)""
;#############################################################################
;	Configuration
;#############################################################################

	__CONFIG	_CONFIG1, 	_CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & _WDT_OFF & _INTRC_IO
	__CONFIG	_CONFIG2, 	_IESO_OFF & _FCMEN_OFF

;#############################################################################
;	Pinout
;#############################################################################

; PIC16F88:
; pin  1 IOA PORTA2	I ADC input
; pin  2 IOA PORTA3	
; pin  3 IOA PORTA4	
; pin  4 I__ PORTA5	MCLR (VPP)
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	
; pin  7 IO_ PORTB1	
; pin  8 IOR PORTB2	I UART RX
; pin  9 IO_ PORTB3	

; pin 10 IO_ PORTB4	I UART CTS
; pin 11 IOT PORTB5	O UART TX
; pin 12 IOA PORTB6	I ICSP PGC
; pin 13 IOA PORTB7	I ICSP PGD
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	
; pin 16 I_X PORTA7	
; pin 17 IOA PORTA0	
; pin 18 IOA PORTA1	



; #DEFINE pin_DRO1_CLOCK	PORTA, 0
#DEFINE pin_ADC_IN		PORTA, 1
#DEFINE pin_ADC_VREFMinus	PORTA, 2
#DEFINE pin_ADC_VREFPlus	PORTA, 3

; #DEFINE pin_KEYPAD_CLOCK	PORTA, 4
;#DEFINE MCLR			PORTA, 5
; #DEFINE pin_KEYPAD_OUTPUT	PORTA, 6
; #DEFINE pin_KEYPAD_INPUT	PORTA, 7

; #DEFINE pin_Disp_CLOCK	PORTB, 0
; #DEFINE pin_Disp0_DATA	PORTB, 1
;#DEFINE UART RX		PORTB, 2
; #DEFINE pin_Disp1_DATA	PORTB, 3

#DEFINE pin_CTS		PORTB, 4
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
data_l			EQU	0x22
data_h			EQU	0x23
ticks			EQU	0x24
data_loop		EQU	0x25
marker			EQU	0x26
marker_offset		EQU	0x27

header_data		EQU	0x28
bit_data		EQU	0x30 ; to 0x58, 40 bytes

fake_data		EQU	0x60
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
	;BCF	pin_ADC		; adc pull up disabled
	BSF	pin_CTS	
	BANK1
	
	

	
	; init port directions
	CLRF	TRISA		; all outputs
	BSF	pin_ADC_IN	; pin1 RA1 adc input
	BSF	pin_ADC_VREFPlus	; pin1 RA1 adc input
	BSF	pin_ADC_VREFMinus; pin1 RA1 adc input
	CLRF	TRISB		; all outputs
	BSF	pin_CTS		; uart TX cts input
	
	; init analog inputs
	CLRF	ANSEL		; all digital
	BSF	ANSEL, 1	; analog input RA1 AN1 
	BSF	ANSEL, 2	; analog input RA2 VREF-
	BSF	ANSEL, 3	; analog input RA3 VREF+

	
	; init osc 8MHz internal
	BCF	OSCCON, SCS0 ;per config
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
	
	;set 9600 baud rate
	BSF 	TXSTA, BRGH	; high speed baud rate generator	
	MOVLW	51		; 9600 bauds
	MOVWF	SPBRG
	
	; timer 0
	; BCF	OPTION_REG, T0CS ; on instruction clock
	; BCF	OPTION_REG, PSA ; pre scaler assigned to tmr0
	; BCF	OPTION_REG, PS2 ; 0
	; BSF	OPTION_REG, PS1 ; 1
	; BCF	OPTION_REG, PS0 ; 0 for 1:8 tmr0 ps
	; ; tmr0 overlfow every 8*256 instructions, or 2048 instructions / 1.024ms

	; BCF	PIE1, TMR1IE	; TMR1 interrupt
	
	BCF	ADCON1, ADFM	;result left justified, 6 lsb of ADRESL are 0
	BSF	ADCON1, VCFG0	;vref+ 
	BSF	ADCON1, VCFG1	;vref- 
	BCF	ADCON1, ADCS2	;clock divider not used with internal
	
	BANK0
	
	
	BSF	ADCON0, ADCS0	;fosc in internal ADC RC clock
	BSF	ADCON0, ADCS1	;	
	BSF	ADCON0, ADON	;adc module ON	
	
	BSF	ADCON0, CHS0
	BCF	ADCON0, CHS1 ; an1
	BCF	ADCON0, CHS2
	
	; ports
	CLRF	PORTA
	CLRF	PORTB	
	
	;BSF	PORTB, 5

	; timer1
	CLRF	TMR1L
	CLRF	TMR1H
	BCF	T1CON, T1CKPS0	; 0
	BSF	T1CON, T1CKPS1	; 1
	; ; pre scaler is 1:4, overlfow of 65536 instructions cycles is 131ms
	BCF	T1CON, TMR1CS	; timer1 clock is FOSC/4
	BSF	T1CON, TMR1ON	; timer1 ON
	
	; UART
	BSF	RCSTA, SPEN	; serial port enabled

; enable interrupts
	; BCF	INTCON, PEIE ; enable peripheral int
	; BCF	INTCON, TMR0IF; clear flag
	; BCF	INTCON, TMR0IE; enable tmr0 interrupt
	; CLRF	TMR0; clear tmr0

	BCF	INTCON, GIE
	
;#############################################################################
;	Program start 
;#############################################################################
nb	EQU	18
MAIN:
	STR	255, ticks
	
	;header is 1D 76 30 00 28 00 01 00 single line of 40 bytes of 8bit raster	
	STR	0x1D, header_data
	STR	0x76, header_data + 1
	STR	0x30, header_data + 2
	STR	0x03, header_data + 3 ; 100x 100 dpi
	
	STR	nb, header_data + 4 ;40
	STR	0x00, header_data + 5
	STR	0x01, header_data + 6;1
	STR	0x00, header_data + 7
	
	MOVLW	'P'
	CALL	SEND_CHAR
	MOVLW	'I'
	CALL	SEND_CHAR	
	MOVLW	'C'
	CALL	SEND_CHAR
	MOVLW	' '
	CALL	SEND_CHAR
	
	MOVLW	'P'
	CALL	SEND_CHAR
	MOVLW	'l'
	CALL	SEND_CHAR
	MOVLW	'o'
	CALL	SEND_CHAR
	MOVLW	't'
	CALL	SEND_CHAR
	MOVLW	't'
	CALL	SEND_CHAR
	MOVLW	'e'
	CALL	SEND_CHAR
	MOVLW	'r'
	CALL	SEND_CHAR
	
	MOVLW	0x0A
	CALL	SEND_CHAR
	
	
	
LOOP:

	BSF	ADCON0, GO	; start conversion
LoopADC_Wait:
	BTFSC	ADCON0, GO	; pool GO/Done for 0
	GOTO	LoopADC_Wait
	
	;BSF	STATUS, RP0 	;BANK1
	;MOVF	ADRESL, W	
	;BCF	STATUS, RP0 	;BANK0
	;MOVWF	data_l
	MOVF	ADRESH, W
	MOVWF	data_h
	;INCF	fake_data, F
	;INCF	fake_data, F
	;MOVF	fake_data, W
	;MOVWF	data_h
	
	; plot result
	
	STR	40, data_loop

; 0  1010101010101010....
; 1  0
; 2  1000 0000  0010 0000  0000 1000  0000 0010  0000 0000  ...1000 0000
; 3  0 
; 4  1 000000000   1 000000000   1 000000000   1  00000000   1....
; 5
; 6
; 7
; 8
; 9 0 (reset ticks to 0)
; 0  1010101010101010....

	INCF	ticks, F
	MOVLW	10
	SUBWF	ticks, W
	BTFSC	STATUS, Z
	CLRF	ticks
	MOVF	ticks, F
	BTFSC	STATUS, Z ; test if == 0
	GOTO	lineMarks
	BTFSC	ticks, 0
	GOTO	noMarks
	GOTO	allMarks

loop_end:
	CALL	MARK_DATA
	CALL	SEND_DATA
	CALL	WAIT_50ms
	CALL	WAIT_50ms
	GOTO	LOOP
	
allMarks:
	MOVLW	b'10000000'
	MOVWF	bit_data
	MOVWF	bit_data + 5
	MOVWF	bit_data + 10
	MOVWF	bit_data + 15
	MOVWF	bit_data + 20
	MOVWF	bit_data + 25
	MOVWF	bit_data + 30
	MOVWF	bit_data + 35

	MOVLW	b'00100000'
	MOVWF	bit_data + 1
	MOVWF	bit_data + 5 + 1
	MOVWF	bit_data + 10 + 1
	MOVWF	bit_data + 15 + 1
	MOVWF	bit_data + 20 + 1
	MOVWF	bit_data + 25 + 1
	MOVWF	bit_data + 30 + 1
	MOVWF	bit_data + 35 + 1
	
	MOVLW	b'00001000'
	MOVWF	bit_data + 2
	MOVWF	bit_data + 5 + 2
	MOVWF	bit_data + 10 + 2
	MOVWF	bit_data + 15 + 2
	MOVWF	bit_data + 20 + 2
	MOVWF	bit_data + 25 + 2
	MOVWF	bit_data + 30 + 2
	MOVWF	bit_data + 35 + 2
	
	MOVLW	b'00000010'
	MOVWF	bit_data + 3
	MOVWF	bit_data + 5 + 3
	MOVWF	bit_data + 10 + 3
	MOVWF	bit_data + 15 + 3
	MOVWF	bit_data + 20 + 3
	MOVWF	bit_data + 25 + 3
	MOVWF	bit_data + 30 + 3
	MOVWF	bit_data + 35 + 3
	
	MOVLW	b'00000000'
	MOVWF	bit_data + 4
	MOVWF	bit_data + 5 + 4
	MOVWF	bit_data + 10 + 4
	MOVWF	bit_data + 15 + 4
	MOVWF	bit_data + 20 + 4
	MOVWF	bit_data + 25 + 4
	MOVWF	bit_data + 30 + 4
	MOVWF	bit_data + 35 + 4
	
	GOTO	loop_end

noMarks:
	MOVLW	40
	MOVWF	data_loop
	
	MOVLW	bit_data
	MOVWF	FSR
noMarks_loop:
	CLRF	INDF
	INCF	FSR, F
	DECFSZ	data_loop, F
	GOTO	noMarks_loop
	
	GOTO	loop_end
	
lineMarks:
	MOVLW	40
	MOVWF	data_loop
	
	MOVLW	bit_data
	MOVWF	FSR
lineMarks_loop:
	MOVLW	b'10101010'
	MOVWF	INDF
	INCF	FSR, F
	DECFSZ	data_loop, F
	GOTO	lineMarks_loop
	
	GOTO	loop_end
	

;#############################################################################
;	SUBROUTINES
;#############################################################################

SEND_DATA:	; sync send 8bytes header + 40 bytes of data with DTR/CTS flow control

	MOVLW	8 + nb
	MOVWF	data_loop
	
	MOVLW	header_data
	MOVWF	FSR
	
SEND_DATA_loopCTS:
	BTFSC	pin_CTS
	GOTO	SEND_DATA_loopCTS	

SEND_DATA_loopSEND:	; send byte to UART, blocking
	BTFSS	PIR1, TXIF
	GOTO	SEND_DATA_loopSEND
	MOVF	INDF, W
	MOVWF	TXREG
	CALL	WAIT_50us
	INCF	FSR, F
	DECFSZ	data_loop, F
	GOTO 	SEND_DATA_loopCTS
	
	RETURN
	
	
MARK_DATA: ; set 2 bits around ADC result in the 40 data raster bits for the printer
	BCF	STATUS, C
	RRF	data_h, F ; /2 because max is 128
	MOVF	data_h, W
	MOVWF	marker_offset
	BCF	STATUS, C
	RRF	marker_offset, F ; /2
	BCF	STATUS, C
	RRF	marker_offset, F ; /4
	BCF	STATUS, C
	RRF	marker_offset, F ; /8
	
	MOVLW	bit_data
	MOVWF	FSR
	MOVF	marker_offset, W
	ADDWF	FSR, F
	
	MOVLW	b'11000000'
	MOVWF	marker
	
	MOVLW	b'00000111'
	ANDWF	data_h, F
	BTFSC	STATUS, Z
	GOTO	MARK_DATA_m
	
	MOVLW	7
	SUBWF	data_h, W
	BTFSS	STATUS, Z
	GOTO	MARK_DATA_l
	INCF	FSR, F
	BSF	INDF, 7
	DECF	FSR, F
	
MARK_DATA_l:
	BCF	STATUS, C
	RRF	marker, F
	DECFSZ	data_h, F
	GOTO	MARK_DATA_l
	
MARK_DATA_m:
	MOVF	marker, W
	IORWF	INDF, F
	RETURN
	
SEND_CHAR:
	BTFSC	pin_CTS
	GOTO	SEND_CHAR	
SEND_CHAR_loop:	; send byte to UART, blocking
	BTFSS	PIR1, TXIF
	GOTO	SEND_CHAR_loop
	MOVWF	TXREG
	RETURN

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
;	End Declaration
;#############################################################################

	END

	
	
	
	
	
	
	
	
