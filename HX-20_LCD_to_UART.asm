;#############################################################################
;
;       Epson HX-20 LCD Module replacement interface test
;       Output: UART at 1250000 bauds (SYNC0 BRGH1 SPBRG0)
;       Exteranl Clock source at 20MHz 5MOPS 0.2us per ops
;
;#############################################################################
;
;       Version 01
;	Detect CSx change
;	Pass All Data to UART
;	Packet byte 1 is high nibble selected chip, low nibble data type ( 0ccc 000t )
;	Packet byte 2 is data packet
;	Packet byte 3? is 0xFF
;
;#############################################################################
;
; Idle state, wait for CS low for capture
; Capture state, wait for SCK and capture data, then set busy low, parse and manage data
; 	When capturing always check for CS going high and cancel capture
;

	LIST		p=16F88			;Processor
	#INCLUDE	<p16F88.inc>	;Processor Specific Registers
	#INCLUDE	<PIC16F88_Macro.asm>	;Bank switching, 16bit methods , wrapped jumps 

	__CONFIG	_CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_OFF & _PWRTE_ON & _WDT_OFF &_EXTCLK; _INTRC_IO;_EXTCLK
	__CONFIG	_CONFIG2, _IESO_OFF & _FCMEN_ON

; cmd.exe /k ""C:/Prog/PIC/MPASM 560/MPASMx" /c- /e=CON /q+ /m+ /x- /rDEC  "$(FULL_CURRENT_PATH)""
	ERRORLEVEL -302		; suppress "bank" warnings
	
;#############################################################################
;	Pinout
;#############################################################################

; PIC16F88
;
; pin  1 IOA PORTA2	I HX_CS2
; pin  2 IOA PORTA3	I HX_CS3
; pin  3 IOA PORTA4	I HX_CS4
; pin  4 I__ PORTA5	I HX_CS5
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O [TFT_A0]
; pin  7 IO_ PORTB1	O [SSP_SDI]
; pin  8 IOR PORTB2	O UART_RX [SSP_SDO]
; pin  9 IO_ PORTB3	O [TFT_RST]

; pin 10 IO_ PORTB4	O HX_CD (#Data/Command) [SSP_SCK]
; pin 11 IOT PORTB5	O UART_TX [TFT_CS]
; pin 12 IOA PORTB6	I HX_SCK
; pin 13 IOA PORTB7	I HX_SDA
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O HX_BUSY (#Busy/SDAout)
; pin 16 I_X PORTA7	OSC Input (20MHz)
; pin 17 IOA PORTA0	I HX_CS0
; pin 18 IOA PORTA1	I HX_CS1

; HX-20 LCD Module Connector (0.050 pitch flex ribbon)
;
; Pin  1	GND
; Pin  2	CS0
; Pin  3	CS4
; Pin  4	CS2
; Pin  5	CS1
; Pin  6	CS3
; Pin  7	CS5
; Pin  8	CLK (osc in for LCD modules)
; Pin  9	Reset
; Pin 10	SDAin
; Pin 11	#DATA/COMMAND
; Pin 12	#BUSY/SDAout
; Pin 13	#SCK
; Pin 14	VCC / Vlcd (from contrast pot)


;#############################################################################
;	Pin Definitions
;#############################################################################

; UART
#DEFINE PIN_UART_RX	PORTB, 2
#DEFINE PIN_UART_TX  	PORTB, 5 ; out

; Epson HX-20 LCD Module Interface
#DEFINE PIN_HX_SDA	PORTB, 7
#DEFINE PIN_HX_SCK	PORTB, 6

#DEFINE PIN_HX_CD	PORTB, 4 

#DEFINE PIN_HX_BUSY	PORTA, 6 ; out

#DEFINE PIN_HX_CS0 	PORTA, 0
#DEFINE PIN_HX_CS1 	PORTA, 1
#DEFINE PIN_HX_CS2 	PORTA, 2
#DEFINE PIN_HX_CS3	PORTA, 3
#DEFINE PIN_HX_CS4	PORTA, 4
#DEFINE PIN_HX_CS5	PORTA, 5

PIN_HX_CS_mask	EQU	b'00111111'

;#############################################################################
;	Command Constants
;#############################################################################


_HX_LOAD	EQU	0x80 ; bits 6 5 4 3 2 1 0 are pointer
_HX_LOAD_mask	EQU	b'10000000'
_HX_WRITE	EQU	0x64 ; bits 0 1 are pointer
_HX_AND		EQU	0x6C ; bits 0 1 are pointer
_HX_OR		EQU	0x68 ; bits 0 1 are pointer
_HX_WRITE_mask	EQU	b'11111100'
_HX_BITSET	EQU	0x40 ; set bit, 4 3 2 1 0 are pointer
_HX_BITRESET	EQU	0x20 ; clear bitm 4 3 2 1 0 are pointer
_HX_BIT_mask	EQU	b'11100000'
_HX_ENABLE	EQU	0x09
_HX_DISABLE	EQU	0x08

;#############################################################################
;	RAM layout
;#############################################################################

d1              EQU     0x20 ; loop 1 var
d2              EQU     0x21 ; loop 2 var
d3              EQU     0x22 ; loop 3 var
SPI_Buffer      EQU     0x23 ; Buffer to test and serialize data for SPI commands
ClearColorL     EQU     0x24
ClearColorH     EQU     0x25
FontColorL	EQU	0x26
FontColorH	EQU	0x27
In_Data		EQU	0x28 ; char line bitmap data
In_Count	EQU	0x29
In_Data2	EQU	0x2A 

XPos		EQU	0x30 ; Current X pos in display
YPos		EQU	0x31 ; Current Y pos in display

XOffset		EQU	0x32 ; Offsets from CSx chip display area
YOffset		EQU	0x33
LastAddress	EQU	0x34 ; Address sent by the Load Pointer command, incremented after each draw

CS0Pos		EQU	0x40
CS1Pos		EQU	0x41
CS2Pos		EQU	0x42
CS3Pos		EQU	0x43
CS4Pos		EQU	0x44
CS5Pos		EQU	0x45
CSIndex		EQU	0x46
;#############################################################################
;	Reset Vector
;#############################################################################

RESET:
	ORG	0x0000
	GOTO	SETUP
ISR:
	;ORG	0x0004
	;BCF	INTCON, GIE
	;CLRF	TXREG
	;RETFIE
	
SETUP:
	BANK0
	BCF	INTCON, GIE	; clear global interrupts	

	BANK1
	;BCF	OSCCON, SCS0
	;BCF	OSCCON, SCS1
	
	CLRF    ANSEL		; all digital IO

	; Port pin direction
        BCF     PIN_UART_TX
        BSF     PIN_UART_RX
        
        BSF     PIN_HX_SCK
        BSF     PIN_HX_SDA
        BSF     PIN_HX_CD
        BCF     PIN_HX_BUSY
        BSF     PIN_HX_CS0
        BSF     PIN_HX_CS1
        BSF     PIN_HX_CS2
        BSF     PIN_HX_CS3
        BSF     PIN_HX_CS4
        BSF     PIN_HX_CS5

	; init AUSART	
	; transmitter
	;BSF	TXSTA, CSRC	; not used in async - set as clock source master
	BCF 	TXSTA, TX9	; 8 bit tx
	BSF	TXSTA, TXEN	; enable tx
	BCF	TXSTA, SYNC	; async
	
	; set 1250000 baud rate for 20MHz clock
	BSF 	TXSTA, BRGH	; high speed baud rate generator	
	;MOVLW	51
	CLRF	SPBRG
	
	BCF	PIE1, RCIE	; enable rx interrupts
	BCF	PIE1, TXIE	; disable tx interrupts
	
	BANK0

	; receiver
	BSF	RCSTA, SPEN	; serial port enabled
	BCF	RCSTA, RX9	; 8 bit rx
	;BSF	RCSTA, SREN	; not used in async - enable single receive
	BSF	RCSTA, CREN	; enable continuous receive
	BCF	RCSTA, ADDEN	; disable addressing

	BANK0		

	CALL	d120ms

	MOVLW	0x55
	MOVWF	TXREG
	CALL	d50us
	MOVLW	0x55
	MOVWF	TXREG
	CALL	d50us
	
	; default ram state
	
	CLRF	CS0Pos
	CLRF	CS1Pos
	CLRF	CS2Pos
	CLRF	CS3Pos
	CLRF	CS4Pos
	CLRF	CS5Pos
	
	
	CALL	d120ms
	
	MOVLW	'E'
	CALL	SEND_BYTE
	MOVLW	'C'
	CALL	SEND_BYTE
	MOVLW	'2'
	CALL	SEND_BYTE
	MOVLW	'0'
	CALL	SEND_BYTE
	MOVLW	'2'
	CALL	SEND_BYTE
	MOVLW	'5'
	CALL	SEND_BYTE
	MOVLW	0x0D
	CALL	SEND_BYTE
	MOVLW	0x0A
	CALL	SEND_BYTE

;#############################################################################
;	Main Loop
;#############################################################################
	
LOOP:	
	BSF	PIN_HX_BUSY
	MOVLW	b'01000000' ; marker
	CLRF	CSIndex
	; signal ready
	
	; from chip select low to first clock low is 100us
	; from last clock up to next byte first clock up is 70us
	
	; check which chip is selected
	BTFSS	PIN_HX_CS0
	GOTO	Sel0
	BTFSS	PIN_HX_CS1
	GOTO	Sel1
	BTFSS	PIN_HX_CS2
	GOTO	Sel2
	BTFSS	PIN_HX_CS3
	GOTO	Sel3
	BTFSS	PIN_HX_CS4
	GOTO	Sel4
	BTFSS	PIN_HX_CS5
	GOTO	Sel5
	GOTO 	LOOP
	
Sel0:
	;CLRF	XOffset
	;CLRF	YOffset
	MOVLW	0
	MOVWF	CSIndex

	GOTO	Wait_Read
Sel1:
	; MOVLW	40
	; MOVWF	XOffset
	; CLRF	YOffset
	MOVLW	1
	MOVWF	CSIndex
	; MOVF	CS1Pos, W
	; MOVWF	XPos
	; MOVLW	16*1
	; MOVWF	YPos
	GOTO	Wait_Read
Sel2:
	; MOVLW	80
	; MOVWF	XOffset
	; CLRF	YOffset
	MOVLW	2
	MOVWF	CSIndex
	; MOVF	CS2Pos, W
	; MOVWF	XPos
	; MOVLW	16*2
	; MOVWF	YPos
	GOTO	Wait_Read
Sel3:
	; CLRF	XOffset
	; MOVLW	16
	; MOVWF	YOffset
	MOVLW	3
	MOVWF	CSIndex
	; MOVF	CS3Pos, W
	; MOVWF	XPos
	; MOVLW	16*3
	; MOVWF	YPos
	GOTO	Wait_Read
Sel4:
	; MOVLW	40
	; MOVWF	XOffset
	; MOVLW	16
	; MOVWF	YOffset
	MOVLW	4
	MOVWF	CSIndex
	; MOVF	CS4Pos, W
	; MOVWF	XPos
	; MOVLW	16*4
	; MOVWF	YPos
	GOTO	Wait_Read
Sel5:
	; MOVLW	80
	; MOVWF	XOffset
	; MOVLW	16
	; MOVWF	YOffset
	MOVLW	5
	MOVWF	CSIndex
	; MOVF	CS5Pos, W
	; MOVWF	XPos
	; MOVLW	16*5
	; MOVWF	YPos
	;GOTO	Wait_Read
	

Wait_Read:
	BTFSC	PIN_HX_CD
	BSF	CSIndex, 7
	
	MOVF	CSIndex, W
	MOVWF	TXREG ; 8us per send, 10 bauds
	
	; TODO add a 120ms timeout that then reset and wait for all CS high
	
	; MOVF	XPos, W
	; SUBLW	126
	; BTFSC	STATUS, C
	; GOTO	Read_Data
	; XORLW	255
	; ADDLW	1
	; MOVWF	XPos
	; MOVLW	8
	; ADDWF	YPos, F
; Wait_Read2:

	; MOVF	XPos, W
	; SUBLW	126
	; BTFSC	STATUS, C
	; GOTO	Read_Data
	; CLRF	XPos
	; MOVLW	8
	; ADDWF	YPos, F
Read_Data:
	CLRF	In_Data
	

Read_Data_Top:
	; MOVLW	PIN_HX_CS_mask
	; ANDWF	PORTA, W
	; XORLW	PIN_HX_CS_mask
	; BTFSC	STATUS, Z
	; GOTO	LOOP
	
	BTFSC	PIN_HX_SCK
	GOTO	$-1;Read_Data_Top
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data, 7
	
	BTFSC	PIN_HX_SCK
	GOTO	$-1
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data, 6
	
	BTFSC	PIN_HX_SCK
	GOTO	$-1
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data, 5
	
	BTFSC	PIN_HX_SCK
	GOTO	$-1
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data, 4
	
	BTFSC	PIN_HX_SCK
	GOTO	$-1
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data, 3
	
	BTFSC	PIN_HX_SCK
	GOTO	$-1
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data, 2
	
	BTFSC	PIN_HX_SCK
	GOTO	$-1
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data, 1
	
	BTFSC	PIN_HX_SCK
	GOTO	$-1
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data, 0

	MOVF	In_Data, W
	MOVWF	TXREG
	
	CLRF	In_Data2

Read_Data_Mid:
	MOVLW	PIN_HX_CS_mask
	ANDWF	PORTA, W
	XORLW	PIN_HX_CS_mask
	BTFSC	STATUS, Z
	GOTO	LOOP

	BTFSC	PIN_HX_SCK
	GOTO	$-1;Read_Data_Mid
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data2, 7
	BTFSC	PIN_HX_SCK
	GOTO	$-1
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data2, 6
	BTFSC	PIN_HX_SCK
	GOTO	$-1
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data2, 5
	BTFSC	PIN_HX_SCK
	GOTO	$-1
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data2, 4
	
	BTFSC	PIN_HX_SCK
	GOTO	$-1
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data2, 3
	BTFSC	PIN_HX_SCK
	GOTO	$-1
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data2, 2
	BTFSC	PIN_HX_SCK
	GOTO	$-1
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data2, 1
	BTFSC	PIN_HX_SCK
	GOTO	$-1
	BTFSS	PIN_HX_SCK
	GOTO	$-1
	BTFSC	PIN_HX_SDA
	BSF	In_Data2, 0
	
	BCF	PIN_HX_BUSY
	; After 2 bytes set busy
	
	MOVF	In_Data2, W
	MOVWF	TXREG
	
	GOTO	LOOP
	
;#############################################################################
;	Delay subroutines for 20MHz
;#############################################################################

d50us: ; delay 50 us: 6ops overhead (1.2us) + 3 (0.6us) per loop, 81 loops
	MOVLW   81
	MOVWF   d1
d50l:
	DECFSZ  d1, F
	GOTO    d50l
	RETURN
	
	
d120ms:	; delay 120ms : header + d1loops * (d1 overhead + (d2loops * (d2 delay)))
	MOVLW   233
	MOVWF   d1
	CLRF    d2
        GOTO    $+1
        NOP
	;header+RETURN : 10 = 2us
d120l:	;2us per d2 loop*256 = 0.512 ms per 256d2
        GOTO    $+1
	GOTO    $+1
	GOTO    $+1
        NOP
	DECFSZ  d2, F
	GOTO    d120l	;loop d2 : 10op / cycles, = 2560 op / d1
	DECFSZ  d1, F
	GOTO    d120l	;loop d1 overhead = 3 
	
	RETURN
	
;#############################################################################
;	UART communication subroutines
;#############################################################################
	
SEND_BYTE:
	BTFSS	PIR1, TXIF
	GOTO	$-1
	MOVWF	TXREG
	RETURN

;#############################################################################
;	EEPROM data for testing
;#############################################################################

	ORG	0x2100 ; the address of EEPROM is 0x2100 
	DE	b'01111100'
        DE	b'00010010'
        DE	b'00010001'
        DE	b'00010010'
        DE	b'01111100'
        DE	b'00000000'
        
        DE	b'01111111'
        DE	b'00010001'
        DE	b'00010001'
        DE	b'00010001'
        DE	b'00010001'
        DE	b'10000000'
	
	END