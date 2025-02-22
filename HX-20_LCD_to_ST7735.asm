;#############################################################################
;
;       Epson HX-20 LCD Module replacement interface
;       Display: ST7735 1.8in 160x128 TFT
;       Exteranl Clock source at 20MHz 5MOPS 0.2us per ops
;
;#############################################################################
;
;       Version 01
;       Initialize TFT
;	Clear
;	Fill Text rate testing
;
;#############################################################################

	LIST		p=16F88			;Processor
	#INCLUDE	<p16F88.inc>	;Processor Specific Registers
	#INCLUDE	<PIC16F88_Macro.asm>	;Bank switching, 16bit methods , wrapped jumps 

	__CONFIG	_CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_OFF & _PWRTE_ON & _WDT_OFF &_EXTCLK; _INTRC_IO;_EXTCLK
	__CONFIG	_CONFIG2, _IESO_OFF & _FCMEN_ON


;#############################################################################
;	Pinout
;#############################################################################

; PIC16F88:
; pin  1 IOA PORTA2	I HX_CS2
; pin  2 IOA PORTA3	I HX_CS3
; pin  3 IOA PORTA4	I HX_CS4 
; pin  4 I__ PORTA5	I HX_CS5 
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O TFT_RST
; pin  7 IO_ PORTB1	O TFT_A0
; pin  8 IOR PORTB2	O TFT_SDA
; pin  9 IO_ PORTB3	O TFT_SCK

; pin 10 IO_ PORTB4	I TFT_CS
; pin 11 IOT PORTB5	I HX_CD
; pin 12 IOA PORTB6	I HX_SDA
; pin 13 IOA PORTB7	I HX_SCK
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O HX_BUSY
; pin 16 I_X PORTA7	OSC Input
; pin 17 IOA PORTA0	I HX_CS0 
; pin 18 IOA PORTA1	I HX_CS1 

; Config - ST7735 SPI TFT
#DEFINE _TFT_CS	        PORTB, 4
#DEFINE _TFT_SCK	PORTB, 3
#DEFINE _TFT_SDA	PORTB, 2
#DEFINE _TFT_A0	        PORTB, 1 ; register select / A0 command:0, data:1
#DEFINE _TFT_RST	PORTB, 0

; Config - Epson HX-20 LCD Module Interface
#DEFINE _HX_SCK	        PORTB, 7
#DEFINE _HX_SDA	        PORTB, 6

#DEFINE _HX_CD  	PORTB, 5
#DEFINE _HX_BUSY	PORTA, 6
#DEFINE _HX_CS0 	PORTA, 0
#DEFINE _HX_CS1 	PORTA, 1

#DEFINE _HX_CS2 	PORTA, 2
#DEFINE _HX_CS3	        PORTA, 3
#DEFINE _HX_CS4	        PORTA, 4
#DEFINE _HX_CS5	        PORTA, 5

; ST7735 TFT Controller Commands
_TFT_SWRESET    EQU 0x01;
_TFT_SLPOUT     EQU 0x11;
_TFT_NORON 	EQU 0x13;
_TFT_DISPON     EQU 0x29;
_TFT_CASET 	EQU 0x2A;
_TFT_RASET 	EQU 0x2B;
_TFT_RAMWR 	EQU 0x2C;
_TFT_MADCTL     EQU 0x36;
_TFT_COLMOD     EQU 0x3A;


;GPR
d1              EQU     0x20
d2              EQU     0x21
d3              EQU     0x22
SPI_Buffer      EQU     0x23
ClearColorL     EQU     0x24
ClearColorH     EQU     0x25
Char_Bitmap	EQU	0x26

Xpos		EQU	0x30
YPos		EQU	0x31

	ORG	0x0000

; setup MCU
	BANK0
	BCF	INTCON, GIE	; clear global interrupts	

	BANK1
	BCF	OSCCON, SCS0
	BCF	OSCCON, SCS1
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
SETUP_OSC:
	BTFSS	OSCCON, IOFS
	GOTO	SETUP_OSC
	
	CLRF    ANSEL		; all digital IO

	; Port pin direction
        BCF     _TFT_CS
        BCF     _TFT_SCK
        BCF     _TFT_SDA
        BCF     _TFT_A0
        BCF     _TFT_RST
        
        BSF     _HX_SCK
        BSF     _HX_SDA
        BSF     _HX_CD
        BCF     _HX_BUSY
        BSF     _HX_CS0
        BCF     _HX_CS1;;;;
        BCF     _HX_CS2;;;;
        BCF     _HX_CS3;;;;
        BCF     _HX_CS4;;;;
        BSF     _HX_CS5

	BANK0		
	; default state SPI mode 3
	BSF     _TFT_CS
	BSF     _TFT_SCK
	BCF     _TFT_RST

        BCF     _HX_BUSY
	
	BCF     _HX_CS2;;;;
        BCF     _HX_CS3;;;;
        BCF     _HX_CS4;;;;
        BCF     _HX_CS1;;;;

;setup TFT
	BSF     _HX_CS2
	; reset TFT	
	CALL    d50us	;actual minimum is 10us or 20 ops
	BSF     _TFT_RST
	CALL    d50us	
	MOVLW   _TFT_SWRESET
	CALL    TFT_SEND_CMD
	CALL    d120ms
	
	BSF     _HX_CS3

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
	MOVLW   5 ;0x9F			; end l 0x9F = 160 pixels wide
	CALL    TFT_SEND_DATA

	MOVLW   _TFT_CASET
	CALL    TFT_SEND_CMD	
	CLRW				; begin h 0x00
	CALL    TFT_SEND_DATA
	CLRW				; begin l 0x00
	CALL    TFT_SEND_DATA
	CLRW				; end h 0x00
	CALL    TFT_SEND_DATA
	MOVLW   7 ;0x7F			; end ; 0x7F = 128 pixels high
	CALL    TFT_SEND_DATA

	; clear RAM
	CLRF    ClearColorL
	CLRF    ClearColorH

	;CALL    TFT_FILL_CHAR

	; turn display on
	MOVLW   _TFT_DISPON
	CALL    TFT_SEND_CMD	


	MOVLW	0x00
	MOVWF	XPos
	MOVLW	0x00
	MOVWF	YPos
	

	BSF     _HX_CS4
MAIN:
	
LOOP:	
	
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
	ADDLW   7 ;0x9F		; end l 0x9F = 160 pixels wide
	CALL    TFT_SEND_DATA
	
	MOVLW	_TFT_RAMWR
	CALL	TFT_SEND_CMD
	
	; draw A
	BANKSEL	EEADR	; Select Bank of EEADR
	MOVLW	0xFF	; Address const
	MOVWF	EEADR 	; Data Memory Address to read
	BANKSEL	d2
	MOVLW	6
	MOVWF	d2
schar:
	BANKSEL	EEADR	; Select Bank of EEADR
	INCF	EEADR, F
	BANKSEL	EECON1	; Select Bank of EECON1
	BCF	EECON1, EEPGD; Point to Data memory

	BSF 	EECON1, RD ; EE Read
	BANKSEL	EEDATA ; Select Bank of EEDATA
	MOVF	EEDATA, W ; W = EEDATA
	BANKSEL	Char_Bitmap
	MOVWF	Char_Bitmap
	
	MOVLW	8
	MOVWF	d3
scol:

	RRF	Char_Bitmap, F
	BTFSC	STATUS, C
	GOTO	$+4
	CALL	TFT_SEND_DATA0
	CALL	TFT_SEND_DATA0
	GOTO	$+3
	CALL	TFT_SEND_DATA1
	CALL	TFT_SEND_DATA1
	DECFSZ	d3, F
	GOTO	scol
	
	DECFSZ	d2, F
	GOTO	schar
	
	BSF     _HX_CS1
	; draw F
	;CALL	d120ms
	
	MOVLW	6
	ADDWF	XPos, F

	
	MOVLW   _TFT_RASET
	CALL    TFT_SEND_CMD
	CALL    TFT_SEND_DATA0
	MOVF	XPos, W
	CALL    TFT_SEND_DATA
	CALL    TFT_SEND_DATA0
	MOVF	XPos, W	
	ADDLW   5
	CALL    TFT_SEND_DATA
	
	MOVLW	_TFT_RAMWR
	CALL	TFT_SEND_CMD
	
	; draw F.
	MOVLW	6
	MOVWF	d2
schar2:
	BANKSEL	EEADR	; Select Bank of EEADR
	INCF	EEADR, F
	BANKSEL	EECON1	; Select Bank of EECON1
	BCF	EECON1, EEPGD; Point to Data memory

	BSF 	EECON1, RD ; EE Read
	BANKSEL	EEDATA ; Select Bank of EEDATA
	MOVF	EEDATA, W ; W = EEDATA
	BANKSEL	Char_Bitmap
	MOVWF	Char_Bitmap
	
	MOVLW	8
	MOVWF	d3
scol2:
	RRF	Char_Bitmap, F
	BTFSC	STATUS, C
	GOTO	$+4
	CALL	TFT_SEND_DATA0
	CALL	TFT_SEND_DATA0
	GOTO	$+3
	CALL	TFT_SEND_DATA1
	CALL	TFT_SEND_DATA1
	DECFSZ	d3, F
	GOTO	scol2
	
	DECFSZ	d2, F
	GOTO	schar2
	
	BCF     _HX_CS1
	; draw F
	;CALL	d120ms

	
	MOVLW	6
	ADDWF	XPos, F
	MOVLW	150;118
	SUBWF	XPos, W
	BTFSS	STATUS, C
	GOTO	aaa
	CLRF	XPos
	MOVLW	8
	ADDWF	YPos, F
	MOVLW	122;30
	SUBWF	YPos, W
	BTFSS	STATUS, C
	GOTO	aaa
	CLRF	YPos
	CALL	TFT_Clear
aaa:
	
	
	
	GOTO    LOOP

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
	BCF     _TFT_A0
	GOTO    TFT_TX_BYTE
	
TFT_SEND_DATA:	; send data in W
	BSF     _TFT_A0

TFT_TX_BYTE:	; very fast and ugly version
	MOVWF   SPI_Buffer	; byte to send in internal buffer
	BCF     _TFT_CS	
	GOTO    $+1
	
	BCF     _TFT_SCK	;clk down
	BCF     _TFT_SDA	;pre clear data bit
	BTFSC   SPI_Buffer, 7 	;check actual data
	BSF     _TFT_SDA 	;if nec set data bit
	NOP
	BSF     _TFT_SCK	;clk up

	BCF     _TFT_SCK
	BCF     _TFT_SDA
	BTFSC   SPI_Buffer, 6
	BSF     _TFT_SDA
	NOP
	BSF     _TFT_SCK

        BCF     _TFT_SCK
	BCF     _TFT_SDA
	BTFSC   SPI_Buffer, 5
	BSF     _TFT_SDA
	NOP
	BSF     _TFT_SCK
        
        BCF     _TFT_SCK
	BCF     _TFT_SDA
	BTFSC   SPI_Buffer, 4
	BSF     _TFT_SDA
	NOP
	BSF     _TFT_SCK
        
        BCF     _TFT_SCK
	BCF     _TFT_SDA
	BTFSC   SPI_Buffer, 3
	BSF     _TFT_SDA
	NOP
	BSF     _TFT_SCK
        
        BCF     _TFT_SCK
	BCF     _TFT_SDA
	BTFSC   SPI_Buffer, 2
	BSF     _TFT_SDA
	NOP
	BSF     _TFT_SCK
        
        BCF     _TFT_SCK
	BCF     _TFT_SDA
	BTFSC   SPI_Buffer, 1
	BSF     _TFT_SDA
	NOP
	BSF     _TFT_SCK
        
        BCF     _TFT_SCK
	BCF     _TFT_SDA
	BTFSC   SPI_Buffer, 0
	BSF     _TFT_SDA
	NOP
	BSF     _TFT_SCK

	GOTO    $+1
	BSF     _TFT_CS		
	RETURN
	
TFT_SEND_DATA0:	; send data 0
	BSF     _TFT_A0
	BCF     _TFT_CS	
	
	BCF	_TFT_SDA
	
	BCF     _TFT_SCK	;clk down
	BSF     _TFT_SCK	;clk up

	BCF     _TFT_SCK
	BSF     _TFT_SCK

        BCF     _TFT_SCK
	BSF     _TFT_SCK
        
        BCF     _TFT_SCK
	BSF     _TFT_SCK
        
        BCF     _TFT_SCK
	BSF     _TFT_SCK
        
        BCF     _TFT_SCK
	BSF     _TFT_SCK
        
        BCF     _TFT_SCK
	BSF     _TFT_SCK
        
        BCF     _TFT_SCK
	BSF     _TFT_SCK

	BSF     _TFT_CS
	
	RETURN
	
TFT_SEND_DATA1:	; send data 1
	BSF     _TFT_A0
	BCF     _TFT_CS	
	
	BSF	_TFT_SDA
	
	BCF     _TFT_SCK	;clk down
	BSF     _TFT_SCK	;clk up

	BCF     _TFT_SCK
	BSF     _TFT_SCK

        BCF     _TFT_SCK
	BSF     _TFT_SCK
        
        BCF     _TFT_SCK
	BSF     _TFT_SCK
        
        BCF     _TFT_SCK
	BSF     _TFT_SCK
        
        BCF     _TFT_SCK
	BSF     _TFT_SCK
        
        BCF     _TFT_SCK
	BSF     _TFT_SCK
        
        BCF     _TFT_SCK
	BSF     _TFT_SCK

	BSF     _TFT_CS		
	RETURN
	
TFT_Clear:
	MOVLW   _TFT_RASET
	CALL    TFT_SEND_CMD
	CALL    TFT_SEND_DATA0
	CALL    TFT_SEND_DATA0
	CALL    TFT_SEND_DATA0 
	MOVLW	160-1;120-1
	CALL    TFT_SEND_DATA
	
	MOVLW   _TFT_CASET
	CALL    TFT_SEND_CMD
	CALL    TFT_SEND_DATA0
	CALL    TFT_SEND_DATA0
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
	CALL	TFT_SEND_DATA0
	CALL	TFT_SEND_DATA0
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