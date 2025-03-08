;#############################################################################
;
;       SPI Interface test for TFT display
;       3.5in IL19488 320x480
;       Exteranl Clock source at 20MHz 5MOPS 0.2us per ops
;	3.3v
;
;#############################################################################
;
;       Version 01
;       Initialize TFT
;	Clear
;	Fill Text rate testing
;	Software vs Hardware SPI testing
;	Draw 4x4 bin bitmap of char
;
;#############################################################################

	LIST		p=16F88			;Processor
	#INCLUDE	<p16F88.inc>	;Processor Specific Registers
	#INCLUDE	<PIC16F88_Macro.asm>	;Bank switching, 16bit methods , wrapped jumps 

	__CONFIG	_CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_ON & _WDT_OFF &_INTRC_IO; _INTRC_IO;_EXTCLK
	__CONFIG	_CONFIG2, _IESO_OFF & _FCMEN_ON
; cmd.exe /k ""C:/Prog/PIC/MPASM 560/MPASMx" /c- /e=CON /q+ /m+ /x- /rDEC  "$(FULL_CURRENT_PATH)""
	ERRORLEVEL -302		; suppress "bank" warnings
;#############################################################################
;	Pinout
;#############################################################################

; PIC16F88:
; pin  1 IOA PORTA2	I 
; pin  2 IOA PORTA3	I 
; pin  3 IOA PORTA4	I  
; pin  4 I__ PORTA5	I  
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O TFT_A0
; pin  7 IO_ PORTB1	O SSP_SDI 
; pin  8 IOR PORTB2	O SSP_SDO 
; pin  9 IO_ PORTB3	O TFT_RST

; pin 10 IO_ PORTB4	0 SSP_SCK 
; pin 11 IOT PORTB5	O TFT_CS
; pin 12 IOA PORTB6	I 
; pin 13 IOA PORTB7	I 
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O 
; pin 16 I_X PORTA7	OSC Input
; pin 17 IOA PORTA0	I  
; pin 18 IOA PORTA1	I  

; Config - IL19488 SPI TFT

#DEFINE PIN_TFT_CS	PORTB, 5 ; active low
#DEFINE PIN_SSP_SCK	PORTB, 4 ; active low
#DEFINE	PIN_TFT_RST	PORTB, 3
#DEFINE PIN_SSP_SDO	PORTB, 2 ; mode is sck idle low, latch on rising edge
#DEFINE PIN_SSP_SDI	PORTB, 1
#DEFINE PIN_TFT_A0	PORTB, 0 ; register select Data/#Cmd  A0 command:0, data:1

; IL19488 TFT Controller Commands
_TFT_SWRESET    EQU 0x01 ; 
_TFT_SLPOUT     EQU 0x11 ; 
_TFT_NORON 	EQU 0x13 ; 
_TFT_DISPON     EQU 0x29 ; 
_TFT_CASET 	EQU 0x2A ; 
_TFT_RASET 	EQU 0x2B ; 
_TFT_RAMWR 	EQU 0x2C ; 
_TFT_MADCTL     EQU 0x36 ; 
_TFT_IDLEOFF	EQU 0x38 ; 
_TFT_COLMOD     EQU 0x3A ; Interface Pixel Format

_TFT_XSET	EQU	_TFT_RASET
_TFT_YSET	EQU	_TFT_CASET

;GPR
d1		EQU	0x20 ; main loop
d2		EQU	0x21
d3		EQU	0x22
d1l	EQU     0x23 ; delay loop
d2l	EQU     0x24 ; 
;	EQU     0x25 ; 
Char_Col_Bitmap	EQU	0x26 ; column bitmap data for test and rotate
;	EQU	0x27 ; 
;	EQU     0x28 ; 
;	EQU     0x29 ; 
;	EQU     0x2A ; 
;	EQU     0x2B ; 
;	EQU     0x2C ; 
;	EQU     0x2D ; 
;	EQU     0x2E ; 
;	EQU     0x2F ; 

Xpos		EQU	0x30 ; XposL, 0x31 is XposH
;XposH	EQU     0x31
Ypos		EQU	0x32 ; YposL, 0x33 is YposH
;YposH	EQU     0x33
Npos		EQU	0x34 ; Next pos Low, 0x35 is NposH
;NposH	EQU	0x35
Counter		EQU	0x3F

DataBatch	EQU	0x40 ; to 0x46 pixel bitmap column byte
DataTypes	EQU	0x4A ; to 0x4F command or data

CharData	EQU	0x50 ; 0x50 to 0x55 is a char to draw

; MACRO

ADDsFast 	MACRO df, sf
	MOVF	sf, W
	ADDWF 	df, F
	BTFSC	STATUS, C
	INCF	df+1, F
	MOVF	sf+1, W
	ADDWF	df+1, F
	ENDM
	
	
; CODE
	ORG	0x0000

SETUP:
	BANK0
	BCF	INTCON, GIE	; clear global interrupts	

	BANK1
	BCF	OSCCON, SCS0	; no switchover
	BCF	OSCCON, SCS1
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
SETUP_OSC:
	BTFSS	OSCCON, IOFS
	GOTO	SETUP_OSC
	
	CLRF    ANSEL		; all digital IO

	; Port pin direction
        BCF     PIN_TFT_CS
        BCF     PIN_SSP_SCK
        BCF     PIN_SSP_SDO
	BSF	PIN_SSP_SDI
        BCF     PIN_TFT_A0
        BCF     PIN_TFT_RST
        
	BANK0		
	; default state SPI mode 3
	BSF     PIN_TFT_CS
	BCF     PIN_SSP_SCK ; clock idle low
	BSF     PIN_TFT_RST
	
	; initialise SSP for SPI
	BANKSEL	SSPSTAT
	BCF	SSPSTAT, 7 ; SMP sample input at same time
	BSF	SSPSTAT, 6 ; CKE 
	
	BANKSEL	SSPCON
	BCF	SSPCON, 7 ; WCOL clear collision flag
	BCF	SSPCON, 6 ; SSPOV clear receive overflow flag
	BCF	SSPCON, 4 ; CPK low, tx on rising edge
	BCF	SSPCON, 3
	BCF	SSPCON, 2
	BCF	SSPCON, 1
	BCF	SSPCON, 0 ; SSPM 0000 SPI Master Clock at Fosc/4
	BSF	SSPCON, 5 ; SSPEN enable SPI port


MAIN:
	BANK0

	; Reset and initialize TFT	
	CALL    d10ms
	BCF     PIN_TFT_RST
	CALL    d10ms
	BSF     PIN_TFT_RST
	CALL    d10ms
	
	MOVLW   _TFT_SWRESET
	CALL    TFT_SEND_CMD
	CALL    d120ms
	
	MOVLW   _TFT_SLPOUT
	CALL    TFT_SEND_CMD
	
	MOVLW   _TFT_NORON
	CALL    TFT_SEND_CMD	


	;set defaults
 	MOVLW   _TFT_COLMOD
	CALL    TFT_SEND_CMD	  
 	MOVLW   0x01			; SPI 4 wire 3 bit per pixel (2 pixel per byte)
	CALL    TFT_SEND_DATA	  

	MOVLW   _TFT_MADCTL		; MY MX MV ML RGB MH X X
	CALL    TFT_SEND_CMD		;
	MOVLW   b'01000000'		;Vertical mirror, data is bottom-left to top-left, then 1 step right
	CALL    TFT_SEND_DATA 
	
	CALL	TFT_Clear

	MOVLW   _TFT_DISPON
	CALL    TFT_SEND_CMD	

	; Initialize memory
	

	CLRF	XPos
	CLRF	XPos+1
	CLRF	YPos
	CLRF	YPos+1

LOOP:	
	CLRF	XPos
	CLRF	XPos+1
	CLRF	YPos
	CLRF	YPos+1
	
	; draw A
	MOVLW	CharData
	MOVWF	FSR
	MOVLW	6 ; 6 columns
	MOVWF	d1
	
	BANKSEL	EEADR	; Select Bank of EEADR
	MOVLW	0-1	; Address const
	MOVWF	EEADR 	; Data Memory Address to read

loadCharA:
	BANKSEL	EEADR	; Select Bank of EEADR
	INCF	EEADR, F
	BANKSEL	EECON1	; Select Bank of EECON1
	BCF	EECON1, EEPGD; Point to Data memory
	BSF 	EECON1, RD ; EE Read
	BANKSEL	EEDATA ; Select Bank of EEDATA
	MOVF	EEDATA, W ; W = EEDATA
	BANKSEL	d1
	MOVWF	INDF
	INCF	FSR, F
	DECFSZ	d1, F
	GOTO	loadCharA
	
	CALL	DrawBin4Char
	CALL	d120ms
	
	MOVLW	32
	MOVWF	Ypos
	MOVWF	Xpos
	CALL	DrawBin4Char
	CALL	d120ms

; draw B
	MOVLW	CharData
	MOVWF	FSR
	MOVLW	6 ; 6 columns
	MOVWF	d1
	
	BANKSEL	EEADR	; Select Bank of EEADR
	MOVLW	6-1	; Address const
	MOVWF	EEADR 	; Data Memory Address to read

loadCharB:
	BANKSEL	EEADR	; Select Bank of EEADR
	INCF	EEADR, F
	BANKSEL	EECON1	; Select Bank of EECON1
	BCF	EECON1, EEPGD; Point to Data memory
	BSF 	EECON1, RD ; EE Read
	BANKSEL	EEDATA ; Select Bank of EEDATA
	MOVF	EEDATA, W ; W = EEDATA
	BANKSEL	d1
	MOVWF	INDF
	INCF	FSR, F
	DECFSZ	d1, F
	GOTO	loadCharB
	
	MOVLW	24
	MOVwf	Xpos
	CLRF	Ypos
	CALL	DrawBin4Char
	CALL	d120ms
	
	MOVLW	32+24
	MOVwf	Xpos
	MOVLW	32
	MOVwf	Ypos
	CALL	DrawBin4Char
	CALL	d120ms
	
; draw C
	MOVLW	CharData
	MOVWF	FSR
	MOVLW	6 ; 6 columns
	MOVWF	d1
	
	BANKSEL	EEADR	; Select Bank of EEADR
	MOVLW	12-1	; Address const
	MOVWF	EEADR 	; Data Memory Address to read

loadCharC:
	BANKSEL	EEADR	; Select Bank of EEADR
	INCF	EEADR, F
	BANKSEL	EECON1	; Select Bank of EECON1
	BCF	EECON1, EEPGD; Point to Data memory
	BSF 	EECON1, RD ; EE Read
	BANKSEL	EEDATA ; Select Bank of EEDATA
	MOVF	EEDATA, W ; W = EEDATA
	BANKSEL	d1
	MOVWF	INDF
	INCF	FSR, F
	DECFSZ	d1, F
	GOTO	loadCharC
	
	MOVLW	48
	MOVwf	Xpos
	CLRF	Ypos
	CALL	DrawBin4Char
	CALL	d120ms
	
	MOVLW	32+48
	MOVwf	Xpos
	MOVLW	32
	MOVwf	Ypos
	CALL	DrawBin4Char
	CALL	d120ms
	
	GOTO    LOOP

;#############################################################################
;	Delay subroutines for 20MHz
;#############################################################################

d50us: ; delay 50 us: 6ops overhead (1.2us) + 3 (0.6us) per loop, 81 loops
	MOVLW   81
	MOVWF   d1l
d50l:
	DECFSZ  d1l, F
	GOTO    d50l
	RETURN
	
d10ms:
	MOVLW	20
	MOVWF	d1l
	CLRF	d2l
	GOTO	$+1
	NOP
d10msLoop:	;2us per d2 loop*256 = 0.512 ms per 256d2
        GOTO    $+1
	GOTO    $+1
	GOTO    $+1
        NOP
	DECFSZ  d2l, F
	GOTO    d10msLoop	;loop d2 : 10op / cycles, = 2560 op / d1
	DECFSZ  d1l, F
	GOTO    d10msLoop	;loop d1 overhead = 3 
	
	RETURN
	
d120ms:	; delay 120ms : header + d1loops * (d1 overhead + (d2loops * (d2 delay)))
	MOVLW   233
	MOVWF   d1l
	CLRF    d2l
        GOTO    $+1
        NOP
	;header+RETURN : 10 = 2us
d120l:	;2us per d2 loop*256 = 0.512 ms per 256d2
        GOTO    $+1
	GOTO    $+1
	GOTO    $+1
        NOP
	DECFSZ  d2l, F
	GOTO    d120l	;loop d2 : 10op / cycles, = 2560 op / d1
	DECFSZ  d1l, F
	GOTO    d120l	;loop d1 overhead = 3 
	
	RETURN
	
;#############################################################################
;	TFT communication subroutines
;#############################################################################
	
TFT_SEND_CMD:	; send command in W
	BCF     PIN_TFT_A0 ; DC is 0 for commands
	GOTO    TFT_TX_BYTE
	
TFT_SEND_DATA:	; send data in W
	BSF     PIN_TFT_A0 ; DC is 1 for data

TFT_TX_BYTE:	; hardware SPI version, async, no interrupt
	BCF     PIN_TFT_CS
	
	MOVWF   SSPBUF		; byte to send in internal buffer
	BSF	STATUS, RP0
	BTFSS	SSPSTAT, BF
	GOTO	$-1
	BCF	SSPSTAT, BF
	BCF	STATUS, RP0
	
	BSF	PIN_TFT_CS
	RETURN
	
TFT_SEND_DATA0:	; send data 0
	BSF     PIN_TFT_A0
	BCF     PIN_TFT_CS
	
	CLRF	SSPBUF
	BSF	STATUS, RP0
	BTFSS	SSPSTAT, BF
	GOTO	$-1
	BCF	SSPSTAT, BF
	BCF	STATUS, RP0
	
	BSF	PIN_TFT_CS
	RETURN
	
TFT_SEND_DATA00: ; send data 00
	BSF     PIN_TFT_A0
	BCF     PIN_TFT_CS
	
	CLRF	SSPBUF
	BSF	STATUS, RP0
	BTFSS	SSPSTAT, BF
	GOTO	$-1
	BCF	SSPSTAT, BF
	BCF	STATUS, RP0
	
	CLRF	SSPBUF
	BSF	STATUS, RP0
	BTFSS	SSPSTAT, BF
	GOTO	$-1
	BCF	SSPSTAT, BF
	BCF	STATUS, RP0
	
	BSF	PIN_TFT_CS
	RETURN
	
TFT_SEND_DATA1:	; send data 1
	BSF     PIN_TFT_A0
	BCF     PIN_TFT_CS
	
	MOVLW	0xFF
	MOVWF	SSPBUF
	BSF	STATUS, RP0
	BTFSS	SSPSTAT, BF
	GOTO	$-1
	BCF	SSPSTAT, BF
	BCF	STATUS, RP0
	
	BSF	PIN_TFT_CS
	RETURN
	
TFT_SEND_DATA11: ; send data 11
	BSF     PIN_TFT_A0
	BCF     PIN_TFT_CS
	
	MOVLW	0xFF
	MOVWF	SSPBUF
	BSF	STATUS, RP0
	BTFSS	SSPSTAT, BF
	GOTO	$-1
	BCF	SSPSTAT, BF
	BCF	STATUS, RP0
	
	MOVWF	SSPBUF
	BSF	STATUS, RP0
	BTFSS	SSPSTAT, BF
	GOTO	$-1
	BCF	SSPSTAT, BF
	BCF	STATUS, RP0
	
	BSF	PIN_TFT_CS
	RETURN
	
TFT_Clear:
	MOVLW   _TFT_CASET ; 0x0140 columns
	CALL    TFT_SEND_CMD
	CALL    TFT_SEND_DATA0
	CALL    TFT_SEND_DATA0
	MOVLW	0x01
	CALL    TFT_SEND_DATA
	MOVLW	0x40-1
	CALL    TFT_SEND_DATA
	
	MOVLW   _TFT_RASET ; 0x01E0 rows
	CALL    TFT_SEND_CMD
	CALL    TFT_SEND_DATA0
	CALL    TFT_SEND_DATA0
	MOVLW	0x01
	CALL    TFT_SEND_DATA
	MOVLW	0xE0-1
	CALL    TFT_SEND_DATA
	
	MOVLW	_TFT_RAMWR
	CALL	TFT_SEND_CMD
	
	MOVLW	75 ; 75 * 8 (4 bytes of 3bpp is 8 pixels) * 256 = 153600 (480*320)
	MOVWF	d1
	CLRF	d2
TFT_ClearCol:
	;MOVLW	0 ; 256
	;MOVWF	d2
TFT_ClearRow:
	CALL	TFT_SEND_DATA0
	CALL	TFT_SEND_DATA1
	CALL	TFT_SEND_DATA0
	CALL	TFT_SEND_DATA1
	DECFSZ	d2, F
	GOTO	TFT_ClearRow
	DECFSZ	d1, F
	GOTO	TFT_ClearCol
	RETURN

TFT_Clear2:
	MOVLW   _TFT_CASET
	CALL    TFT_SEND_CMD
	CALL    TFT_SEND_DATA0
	CALL    TFT_SEND_DATA0
	MOVLW	0x01
	CALL    TFT_SEND_DATA
	MOVLW	0x40-1
	CALL    TFT_SEND_DATA
	
	MOVLW   _TFT_RASET
	CALL    TFT_SEND_CMD
	CALL    TFT_SEND_DATA0
	CALL    TFT_SEND_DATA0
	MOVLW	0x01
	CALL    TFT_SEND_DATA
	MOVLW	0xE0-1
	CALL    TFT_SEND_DATA
	
	MOVLW	_TFT_RAMWR
	CALL	TFT_SEND_CMD
	
	MOVLW	75;32
	MOVWF	d1
	CLRF	d2
TFT_Clear2Col:
	;MOVLW	0;120
	;MOVWF	d2
TFT_Clear2Row:
	CALL	TFT_SEND_DATA1
	CALL	TFT_SEND_DATA0
	CALL	TFT_SEND_DATA1
	CALL	TFT_SEND_DATA0
	DECFSZ	d2, F
	GOTO	TFT_Clear2Row
	DECFSZ	d1, F
	GOTO	TFT_Clear2Col
	RETURN
	
;#############################################################################
;	Char/Bitmap drawing routines
;#############################################################################

DrawBin4Char: ; Send 4x4 binned char data for 8x6 in CharData at Xpos and Ypos

	CLRF	Npos+1
	MOVLW	4*8-1
	MOVWF	Npos
	ADDsFast Npos, Ypos
	
	MOVLW   _TFT_YSET
	CALL    TFT_SEND_CMD
	MOVF	YPos+1, W
	CALL    TFT_SEND_DATA
	MOVF	YPos, W
	CALL    TFT_SEND_DATA
	MOVF	Npos+1, W
	CALL    TFT_SEND_DATA
	MOVF	Npos, W
	CALL    TFT_SEND_DATA
	
	CLRF	Npos+1
	MOVLW	4*6-1
	MOVWF	Npos
	ADDsFast Npos, Xpos
	
	MOVLW   _TFT_XSET
	CALL    TFT_SEND_CMD
	MOVF	Xpos+1, W
	CALL    TFT_SEND_DATA
	MOVF	XPos, W
	CALL    TFT_SEND_DATA
	MOVF	Npos+1, W
	CALL    TFT_SEND_DATA
	MOVF	Npos, W
	CALL    TFT_SEND_DATA
	
	MOVLW	_TFT_RAMWR
	CALL	TFT_SEND_CMD
	BSF     PIN_TFT_A0
	CALL	d120ms

	MOVLW	CharData
	MOVWF	FSR

	MOVLW	6
	MOVWF	d2
	
schar:
	
; Column 1
	MOVF	INDF, W
	MOVWF	Char_Col_Bitmap
	MOVLW	8
	MOVWF	d3
scol1:
	RLF	Char_Col_Bitmap, F
	BTFSC	STATUS, C
	GOTO	$+3
	CALL	TFT_SEND_DATA00
	GOTO	$+2
	CALL	TFT_SEND_DATA11
	CALL	d10ms
	DECFSZ	d3, F
	GOTO	scol1
	
; Column 2
	MOVF	INDF, W
	MOVWF	Char_Col_Bitmap
	MOVLW	8
	MOVWF	d3
scol2:
	RLF	Char_Col_Bitmap, F
	BTFSC	STATUS, C
	GOTO	$+3
	CALL	TFT_SEND_DATA00
	GOTO	$+2
	CALL	TFT_SEND_DATA11
	CALL	d10ms
	DECFSZ	d3, F
	GOTO	scol2
	
; Column 3
	MOVF	INDF, W
	MOVWF	Char_Col_Bitmap
	MOVLW	8
	MOVWF	d3
scol3:
	RLF	Char_Col_Bitmap, F
	BTFSC	STATUS, C
	GOTO	$+3
	CALL	TFT_SEND_DATA00
	GOTO	$+2
	CALL	TFT_SEND_DATA11
	CALL	d10ms
	DECFSZ	d3, F
	GOTO	scol3
	
; Column 4
	MOVF	INDF, W
	MOVWF	Char_Col_Bitmap
	MOVLW	8
	MOVWF	d3
scol4:
	RLF	Char_Col_Bitmap, F
	BTFSC	STATUS, C
	GOTO	$+3
	CALL	TFT_SEND_DATA00
	GOTO	$+2
	CALL	TFT_SEND_DATA11
	CALL	d10ms
	DECFSZ	d3, F
	GOTO	scol4
	
	CALL	d120ms
; Next Bitmap slice
	INCF	FSR, F
	DECFSZ	d2, F
	GOTO	schar
	
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
        DE	b'10000001'
        
        DE	b'01111111'
        DE	b'01001001'
        DE	b'01001001'
        DE	b'01001001'
        DE	b'00110110'
        DE	b'00000000'
	
	DE	b'00111110'
        DE	b'01000001'
        DE	b'01000001'
        DE	b'01000001'
        DE	b'01000001'
        DE	b'00000000'
	
;#############################################################################
;	END Declaration
;#############################################################################
	
	END
