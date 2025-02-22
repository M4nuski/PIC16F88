;#############################################################################
;
;       Epson HX-20 LCD Module replacement interface
;       Display: ST7735 1.8in 160x128 TFT
;       Exteranl Clock source at 20MHz 5MOPS 0.2us per ops
;
;#############################################################################
;
;       Version 02
;	Detect CSx change
;	Set Pointers
;	Pass All Data to TFT
;	Each CS has a line
;	Commands Red Pixels
;	Data White Pixels
;
;#############################################################################
;
; Idle state, wait for CS low for capture or RST high line to get back to default state
; Capture state, wait for SCK and capture data, then set busy low, parse and manage data
; 	When capturing always check for CS going high and cancel capture
;	Going back to the np++ it seems to be fine now with the base CPU is now 5%
;

	LIST		p=16F88			;Processor
	#INCLUDE	<p16F88.inc>	;Processor Specific Registers
	#INCLUDE	<PIC16F88_Macro.asm>	;Bank switching, 16bit methods , wrapped jumps 

	__CONFIG	_CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_OFF & _PWRTE_ON & _WDT_OFF &_EXTCLK; _INTRC_IO;_EXTCLK
	__CONFIG	_CONFIG2, _IESO_OFF & _FCMEN_ON


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
; pin  6 IO_ PORTB0	O TFT_A0
; pin  7 IO_ PORTB1	O TFT_SDA
; pin  8 IOR PORTB2	O TFT_SCK
; pin  9 IO_ PORTB3	O TFT_CS
;
; pin 10 IO_ PORTB4	I HX_RST
; pin 11 IOT PORTB5	I HX_CD
; pin 12 IOA PORTB6	I HX_SDA
; pin 13 IOA PORTB7	I HX_SCK
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O HX_BUSY
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

; TFT ST7735 Module
;
; Pin  1	GND
; Pin  2	VCC (Logic)
; Pin  3	NC
; Pin  4	NC
; Pin  5	NC
; Pin  6	Reset
; Pin  7	A0 (#Command/Data)
; Pin  8	SDA
; Pin  9	SCK 
; Pin 10	CS
; Pin 11	SD SCK
; Pin 12	SD MISO
; Pin 13	SD MOSI
; Pin 14	SD CS
; Pin 15	LED+
; Pin 16	LED-

;#############################################################################
;	Pin Definitions
;#############################################################################

; ST7735 SPI TFT
#DEFINE PIN_TFT_CS	PORTB, 3
#DEFINE PIN_TFT_SCK	PORTB, 2
#DEFINE PIN_TFT_SDA	PORTB, 1 ; register select / A0 command:0, data:1
#DEFINE PIN_TFT_A0	PORTB, 0

; Epson HX-20 LCD Module Interface
#DEFINE PIN_HX_SCK	PORTB, 7
#DEFINE PIN_HX_SDA	PORTB, 6
#DEFINE PIN_HX_CD  	PORTB, 5
#DEFINE PIN_TFT_RST	PORTB, 4 ;;;;;

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

; ST7735 TFT Controller Commands
_TFT_SWRESET    EQU	0x01
_TFT_SLPOUT     EQU	0x11
_TFT_NORON 	EQU	0x13
_TFT_DISPON     EQU	0x29
_TFT_CASET 	EQU	0x2A
_TFT_RASET 	EQU	0x2B
_TFT_RAMWR 	EQU	0x2C
_TFT_MADCTL     EQU	0x36
_TFT_COLMOD     EQU	0x3A

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
	ORG	0x0004
	BCF	INTCON, GIE
	RETFIE
	
SETUP:
	BANK0
	BCF	INTCON, GIE	; clear global interrupts	

	BANK1
	BCF	OSCCON, SCS0
	BCF	OSCCON, SCS1
	;BSF	OSCCON, IRCF0
	;BSF	OSCCON, IRCF1
	;BSF	OSCCON, IRCF2
	
SETUP_OSC:
	;BTFSS	OSCCON, IOFS
	;GOTO	SETUP_OSC
	
	CLRF    ANSEL		; all digital IO

	; Port pin direction
        BCF     PIN_TFT_CS
        BCF     PIN_TFT_SCK
        BCF     PIN_TFT_SDA
        BCF     PIN_TFT_A0
        BCF     PIN_TFT_RST
        
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

	BANK0		
	; default state SPI mode 3
	BSF     PIN_TFT_CS
	BSF	PIN_TFT_SCK

	BCF     PIN_TFT_RST

	; default state HX interface
        BSF     PIN_HX_BUSY
	
	; default ram state
	CLRF	XPos
	CLRF	YPos
	CLRF    ClearColorL
	CLRF    ClearColorH
	MOVLW	0xFF
	MOVWF	FontColorL
	MOVWF	FontColorH
	
	CLRF	CS0Pos
	CLRF	CS1Pos
	CLRF	CS2Pos
	CLRF	CS3Pos
	CLRF	CS4Pos
	CLRF	CS5Pos

;setup TFT

	; reset TFT	
	CALL	d120ms
	
	;CALL    d50us	;actual minimum is 10us or 20 ops
	BSF     PIN_TFT_RST
	MOVLW   _TFT_SWRESET
	CALL    TFT_SEND_CMD
	CALL    d120ms

	; init TFT
	MOVLW   _TFT_SLPOUT
	CALL    TFT_SEND_CMD

	MOVLW   _TFT_NORON
	CALL    TFT_SEND_CMD	

	;set defaults
 	MOVLW   _TFT_COLMOD
	CALL    TFT_SEND_CMD	  
 	MOVLW   0x05			; RGB565
	CALL    TFT_SEND_DATA	  

	MOVLW   _TFT_MADCTL		; MY MX MV ML RGB MH X X
	CALL    TFT_SEND_CMD
	MOVLW   0x44
	CALL    TFT_SEND_DATA 
	
	CALL	TFT_Clear

	MOVLW   _TFT_RASET
	CALL    TFT_SEND_CMD
	CLRW				; begin h 0x00
	CALL    TFT_SEND_DATA
	CLRW				; begin l 0x00
	CALL    TFT_SEND_DATA
	CLRW				; end h 0x00
	CALL    TFT_SEND_DATA 
	MOVLW   5 ;0x9F			; end l 
	CALL    TFT_SEND_DATA

	MOVLW   _TFT_CASET
	CALL    TFT_SEND_CMD	
	CLRW				; begin h 0x00
	CALL    TFT_SEND_DATA
	CLRW				; begin l 0x00
	CALL    TFT_SEND_DATA
	CLRW				; end h 0x00
	CALL    TFT_SEND_DATA
	MOVLW   7 ;0x7F			; end l
	CALL    TFT_SEND_DATA

	; turn display on
	MOVLW   _TFT_DISPON
	CALL    TFT_SEND_CMD	

	;BSF     PIN_HX_CS2 ; initialized

;#############################################################################
;	Main Loop
;#############################################################################
	
LOOP:	
	BSF	PIN_HX_BUSY
	; signal ready

	; from chip select to SCK down is about 70us
	
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
	CLRF	XOffset
	CLRF	YOffset
	; MOVLW	0
	; MOVWF	CSIndex
	; MOVF	CS0Pos, W
	; MOVWF	XPos
	; MOVLW	16*0
	; MOVWF	YPos
	GOTO	Wait_Read
Sel1:
	MOVLW	40
	MOVWF	XOffset
	CLRF	YOffset
	; MOVLW	1
	; MOVWF	CSIndex
	; MOVF	CS1Pos, W
	; MOVWF	XPos
	; MOVLW	16*1
	; MOVWF	YPos
	GOTO	Wait_Read
Sel2:
	MOVLW	80
	MOVWF	XOffset
	CLRF	YOffset
	; MOVLW	2
	; MOVWF	CSIndex
	; MOVF	CS2Pos, W
	; MOVWF	XPos
	; MOVLW	16*2
	; MOVWF	YPos
	GOTO	Wait_Read
Sel3:
	CLRF	XOffset
	MOVLW	16
	MOVWF	YOffset
	; MOVLW	3
	; MOVWF	CSIndex
	; MOVF	CS3Pos, W
	; MOVWF	XPos
	; MOVLW	16*3
	; MOVWF	YPos
	GOTO	Wait_Read
Sel4:
	MOVLW	40
	MOVWF	XOffset
	MOVLW	16
	MOVWF	YOffset
	; MOVLW	4
	; MOVWF	CSIndex
	; MOVF	CS4Pos, W
	; MOVWF	XPos
	; MOVLW	16*4
	; MOVWF	YPos
	GOTO	Wait_Read
Sel5:
	MOVLW	80
	MOVWF	XOffset
	MOVLW	16
	MOVWF	YOffset
	; MOVLW	5
	; MOVWF	CSIndex
	; MOVF	CS5Pos, W
	; MOVWF	XPos
	; MOVLW	16*5
	; MOVWF	YPos
	GOTO	Wait_Read
	

Wait_Read:
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
	MOVLW	PIN_HX_CS_mask
	ANDWF	PORTA, W
	XORLW	PIN_HX_CS_mask
	BTFSC	STATUS, Z
	GOTO	LOOP
	
	BTFSC	PIN_HX_SCK
	GOTO	Read_Data_Top
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


	CLRF	In_Data2

Read_Data_Mid:
	MOVLW	PIN_HX_CS_mask
	ANDWF	PORTA, W
	XORLW	PIN_HX_CS_mask
	BTFSC	STATUS, Z
	GOTO	LOOP

	BTFSC	PIN_HX_SCK
	GOTO	Read_Data_Mid
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
	; Check if Command or Data
	; Parse
	; Draw
	BTFSC	PIN_HX_CD ; Command:1, Data:0
	GOTO	Parse_Command
	
	; calculate offset
	; base y for first line
	CLRW
	BTFSC	LastAddress, 6
	MOVLW	8 ; check if second char line
	ADDWF	YOffset, W
	MOVWF	YPos
	
	; low bits for X
	MOVLW	b'00111111'
	ANDWF	LastAddress, W
	ADDWF	XOffset, W
	MOVWF	XPos
	
	CALL	Draw
	INCF	XPos, F
	INCF	LastAddress, F
	
	MOVF	In_Data2, W
	MOVWF	In_Data
	CALL	Draw
	INCF	LastAddress, F
	
	; MOVLW	CS0Pos
	; ADDWF	CSIndex, W
	; MOVWF	FSR
	; INCF	INDF, F
	; INCF	INDF, F
	; ; move to next column
	; INCF	LastAddress, F
	GOTO	LOOP

Parse_Command:
	BTFSS	In_Data, 7 ; check if bit7 set for Load Pointer command
	GOTO	NotLoad1
	BCF	In_Data, 7
	MOVF	In_Data, W
	MOVWF	LastAddress
NotLoad1:
	BTFSS	In_Data2, 7 ; check if bit7 set for Load Pointer command
	GOTO	NotLoad2
	BCF	In_Data2, 7
	MOVF	In_Data2, W
	MOVWF	LastAddress
	GOTO	LOOP
NotLoad2:
	GOTO	LOOP ; only command so far
	
	; MOVLW 	_HX_WRITE_mask
	; ANDWF	In_Data, W
	; XORLW	_HX_WRITE
	; BTFSC	STATUS, Z
	; GOTO	NotWrite
	; ; Write mode
	; GOTO	LOOP
; NotWrite:
	; XORLW	_HX_AND
	; BTFSC	STATUS, Z
	; GOTO	NotAnd
	; ; And mode
	; GOTO	LOOP

; NotAnd:
	; XORLW	_HX_OR
	; BTFSC	STATUS, Z
	; GOTO	NotOr
	; ; And mode
	; GOTO	LOOP
; NotOr:

	;CALL	Draw
	; parse and execute command
	GOTO	LOOP
	
	
	
Draw:
	MOVLW   _TFT_RASET
	CALL    TFT_SEND_CMD
	CALL    TFT_SEND_DATA0
	MOVF	XPos, W
	CALL    TFT_SEND_DATA
	CALL    TFT_SEND_DATA0 
	MOVF	XPos, W	
	ADDLW	5
	CALL    TFT_SEND_DATA
	
	MOVLW   _TFT_CASET
	CALL    TFT_SEND_CMD
	CALL    TFT_SEND_DATA0
	MOVF	YPos, W
	CALL    TFT_SEND_DATA
	CALL    TFT_SEND_DATA0 
	MOVF	YPos, W	
	ADDLW   7
	CALL    TFT_SEND_DATA
	
	MOVLW	_TFT_RAMWR
	CALL	TFT_SEND_CMD

	MOVLW	8
	MOVWF	d3
Draw_SendLoop:
	RRF	In_Data, F
	BTFSC	STATUS, C
	GOTO	Draw_SendLoopNotZero
	CALL	TFT_SEND_DATA_565_Black
	GOTO	Draw_SendLoopEnd
Draw_SendLoopNotZero:
	;BTFSC	PIN_HX_CD ; Command:1, Data:0
	;GOTO	Draw_SendLoopCommand
	CALL	TFT_SEND_DATA_565_White
	;GOTO	Draw_SendLoopEnd
Draw_SendLoopCommand:
	;CALL	TFT_SEND_DATA_565_Red
Draw_SendLoopEnd:
	DECFSZ	d3, F
	GOTO	Draw_SendLoop

	RETURN
















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
;	TFT communication subroutines
;#############################################################################
	
TFT_SEND_CMD:	; send command in W
	BCF     PIN_TFT_A0
	GOTO    TFT_TX_BYTE
	
TFT_SEND_DATA:	; send data in W
	BSF     PIN_TFT_A0

TFT_TX_BYTE:	; very fast and ugly version
	MOVWF   SPI_Buffer	; byte to send in internal buffer
	BCF     PIN_TFT_CS	
	GOTO    $+1
	
	BCF     PIN_TFT_SCK	;clk down
	BCF     PIN_TFT_SDA	;pre clear data bit
	BTFSC   SPI_Buffer, 7 	;check actual data
	BSF     PIN_TFT_SDA 	;if nec set data bit
	GOTO    $+1
	BSF	PIN_TFT_SCK	;clk up
	;GOTO    $+1	

	
	BCF     PIN_TFT_SCK
	BCF     PIN_TFT_SDA
	BTFSC   SPI_Buffer, 6
	BSF     PIN_TFT_SDA
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1

        BCF     PIN_TFT_SCK
	BCF     PIN_TFT_SDA
	BTFSC   SPI_Buffer, 5
	BSF     PIN_TFT_SDA
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        
        BCF     PIN_TFT_SCK
	BCF     PIN_TFT_SDA
	BTFSC   SPI_Buffer, 4
	BSF     PIN_TFT_SDA
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        
        BCF     PIN_TFT_SCK
	BCF     PIN_TFT_SDA
	BTFSC   SPI_Buffer, 3
	BSF     PIN_TFT_SDA
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        
        BCF     PIN_TFT_SCK
	BCF     PIN_TFT_SDA
	BTFSC   SPI_Buffer, 2
	BSF     PIN_TFT_SDA
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        
        BCF     PIN_TFT_SCK
	BCF     PIN_TFT_SDA
	BTFSC   SPI_Buffer, 1
	BSF     PIN_TFT_SDA
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        
        BCF     PIN_TFT_SCK
	BCF     PIN_TFT_SDA
	BTFSC   SPI_Buffer, 0
	BSF     PIN_TFT_SDA
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1

	GOTO    $+1
	BSF     PIN_TFT_CS		
	RETURN
	
TFT_SEND_DATA0:	; send data 0
	BSF     PIN_TFT_A0
	BCF     PIN_TFT_CS	
	
	BCF	PIN_TFT_SDA
	
	BCF     PIN_TFT_SCK	;clk down
	GOTO    $+1
	BSF	PIN_TFT_SCK	;clk up
	;GOTO    $+1	

	BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1

        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1

	BSF     PIN_TFT_CS
	
	RETURN
	
TFT_SEND_DATA_565_White:
	BSF     PIN_TFT_A0
	BCF     PIN_TFT_CS	
	
	BSF	PIN_TFT_SDA
	;7
	BCF     PIN_TFT_SCK	;clk down
	GOTO    $+1
	BSF	PIN_TFT_SCK	;clk up
	;GOTO    $+1	
	;6
	BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
	;5
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;4
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;3
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;2
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;1
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;0
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
	
	;7
	BCF     PIN_TFT_SCK	;clk down
	GOTO    $+1
	BSF	PIN_TFT_SCK	;clk up
	;GOTO    $+1	
	;6
	BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
	;5
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;4
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;3
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;2
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;1
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;0
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1

	BSF     PIN_TFT_CS
	RETURN



TFT_SEND_DATA_565_Black:
	BSF     PIN_TFT_A0
	BCF     PIN_TFT_CS	
	
	BCF	PIN_TFT_SDA
	;7
	BCF     PIN_TFT_SCK	;clk down
	GOTO    $+1
	BSF	PIN_TFT_SCK	;clk up
	;GOTO    $+1	
	;6
	BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
	;5
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;4
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;3
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;2
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;1
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;0
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
	
	;7
	BCF     PIN_TFT_SCK	;clk down
	GOTO    $+1
	BSF	PIN_TFT_SCK	;clk up
	;GOTO    $+1	
	;6
	BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
	;5
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;4
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;3
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;2
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;1
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1
        ;0
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	;GOTO    $+1

	BSF     PIN_TFT_CS
	RETURN
	
TFT_SEND_DATA_565_Red:
	BSF     PIN_TFT_A0
	BCF     PIN_TFT_CS	
	
	;7 r4
	BCF     PIN_TFT_SCK	;clk down
	BSF	PIN_TFT_SDA
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1	;clk up
	;6 r3
	BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1
	;5 r2
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1
        ;4 r1
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1
        ;3 r0
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1
	
        ;2 g5
        BCF     PIN_TFT_SCK
	BCF	PIN_TFT_SDA
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1
        ;1 g4
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1
        ;0 g3
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1
	;7 g2
	BCF     PIN_TFT_SCK	;clk down
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1	;clk up
	;6 g1
	BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1
	;5 g0
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1
	
        ;4 b4
        BCF     PIN_TFT_SCK
	BCF	PIN_TFT_SDA
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1
        ;3 b3
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1
        ;2 b2
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1
        ;1 b1
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1
        ;0 b0
        BCF     PIN_TFT_SCK
	GOTO    $+1
	BSF	PIN_TFT_SCK
	GOTO    $+1

	BSF     PIN_TFT_CS
	RETURN

TFT_Clear:
	MOVLW   _TFT_RASET
	CALL    TFT_SEND_CMD
	CALL	TFT_SEND_DATA_565_Black
	CALL    TFT_SEND_DATA0 
	MOVLW	160-1;120-1
	CALL    TFT_SEND_DATA
	
	MOVLW   _TFT_CASET
	CALL    TFT_SEND_CMD
	CALL	TFT_SEND_DATA_565_Black
	CALL    TFT_SEND_DATA0 
	MOVLW	128-1;32-1
	CALL    TFT_SEND_DATA
	
	MOVLW	_TFT_RAMWR
	CALL	TFT_SEND_CMD
	
	MOVLW	128;32
	MOVWF	d1
TFT_ClearCol:
	MOVLW	160;120
	MOVWF	d2
TFT_ClearRow:
	CALL	TFT_SEND_DATA_565_Black
	DECFSZ	d2, F
	GOTO	TFT_ClearRow
	DECFSZ	d1, F
	GOTO	TFT_ClearCol
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