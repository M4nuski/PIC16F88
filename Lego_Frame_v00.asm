	LIST	p=16F88		;Processor
	#INCLUDE <p16F88.inc>	;Processor Specific Registers
	#INCLUDE <PIC16F88_Macro.asm>
	
	__CONFIG	_CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_OFF & _PWRTE_ON & _WDT_OFF & _HS_OSC
	__CONFIG	_CONFIG2, _IESO_ON & _FCMEN_ON

; Lego Frame MCU
; Test 00
; Load Flash from W25Q128FV (Winbond) 128mbit / 16mbyte 3V SPI flash 
; Send to ST7735 1.8in 160x128 TFT in portrait mode

; load first bank to read data type, qty, size
; calc offset
; Init ramwrite on tft and read on flash, then only clock data inbetween

; todo: add auto play after 5-10 sec
; todo: add next and previous button with overflow protection

; todo: test speed at internal 8MHz clock rate
; todo: fix pinout and test with final layout 
	
; Bank #    SFR           GPR               SHARED GPR's
; Bank 0    0x00-0x1F     0x20-0x6F         0x70-0x7F    
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF

; SPI 0 Config
#define _SPI0_CS	PORTB, 0
#define _SPI0_CLK	PORTB, 1
#define _SPI0_DTA	PORTB, 2
#define _SPI0_A0	PORTB, 3 ; register select / A0 command:0, data:1

#define _SPI0_RST	PORTB, 4
;#define  		PORTB, 5; unused
;#define		PORTB, 6; reserved for ICSP PGC
;#define		PORTB, 7; reserver for ICSP PGD


#define _SPI1_CLK	PORTA, 0
#define _SPI1_DTAO	PORTA, 1
#define _SPI1_DTAI	PORTA, 2
#define _SPI1_CS	PORTA, 3

#define _SPI1_RST	PORTA, 4 ; unused
;#define _	PORTA, 5 ;in only	; unused
;#define _	PORTA, 6 ;out only ;reserved for OSC
;#define _	PORTA, 7 ;in only  ;reserved for OSC


; at 8MHz, 2Mops, 0.5 us / op. 120ms / 0.5 = 240 000 ops delay
; at 20MHz, 5Mops, 0.2 us / op. 120ms / 0.2 = 600 000 ops delay


; ST7735 TFT Controller command constants
_TFT_SWRESET EQU 0x01;
_TFT_SLPOUT  EQU 0x11;
_TFT_NORON 	 EQU 0x13;
_TFT_DISPON  EQU 0x29;
_TFT_CASET 	 EQU 0x2A;
_TFT_RASET 	 EQU 0x2B;
_TFT_RAMWR 	 EQU 0x2C;
_TFT_MADCTL  EQU 0x36;
_TFT_COLMOD  EQU 0x3A;
	
; W25Q128FV Flash memory command constants

_W25_read  		EQU 0x03
_W25_read_SSR	EQU 0x05;
_W25_read_JEDEC	EQU 0x9F;


;GPR
	cblock 0x020
		d1, d2		; loops counters
		
		SPI_Buffer	; Output buffer for SPI 0 or 1
		ClearColor:3; r g b

		SPI1_Bytes_to_Read:2
		SPI1_Bytes_Counter:2

		; config struct from flash
		ColMod
		MadCtl
		NumImages
		BytesPerImages:2
		
		; state
		CurrentImage
		CurrentAddress:3
		
		SSR
		ID:3
		
	endc

	
	
	ORG	0x0000
	
; setup 
	
	BANK0
	BCF	INTCON, GIE	; clear global interrupts

	BANK1
		; disabled because of external OSC
	;BSF	OSCCON, IRCF0	; internal OSC setup
	;BSF	OSCCON, IRCF1	; 8mhz
	;BSF	OSCCON, IRCF2	

	CLRF ANSEL			; all digital IO
	
	; SPI
	BCF _SPI0_CS
	BCF _SPI0_CLK
	BCF _SPI0_DTA
	BCF _SPI0_RST
	BCF _SPI0_A0
	
	BCF _SPI1_CLK
	BCF _SPI1_DTAO
	BSF _SPI1_DTAI
	BCF _SPI1_CS
	BCF _SPI1_RST

	BANK0	
	
	; default state SPI mode 3
	BSF _SPI0_CS
	BSF _SPI0_CLK
	BSF _SPI0_RST
	
	BSF _SPI1_CS
	BSF _SPI1_CLK
	BCF _SPI1_RST
	
; main
	
	; reset TFT	
	BCF _SPI0_RST
	call d120ms	;actual minimum is 10us or 20 ops
	BSF _SPI0_RST
	call d120ms	
	movlw _TFT_SWRESET
	call SPI0_Send_CMD
	call d120ms
	
	; init TFT
	movlw _TFT_SLPOUT
	call SPI0_Send_CMD
	
	movlw _TFT_NORON
	call SPI0_Send_CMD	
	
 	movlw _TFT_COLMOD
	call SPI0_Send_CMD	  
 	movlw 0x06			;RGB666
	call SPI0_Send_DTA	  
	
	movlw _TFT_MADCTL
	call SPI0_Send_CMD
	movlw 0xA0			;MY1 MX0 MV1 ML0 RGB MH0
	call SPI0_Send_DTA 
	
	movlw _TFT_CASET
	call SPI0_Send_CMD
	CLRW				; offset h 0x00
	call SPI0_Send_DTA
	CLRW				; offset l 0x00
	call SPI0_Send_DTA
	CLRW				; width h 0x00
	call SPI0_Send_DTA 
	movlw 0x9F			; width l 0x9F = 160 pixels wide
	call SPI0_Send_DTA

	movlw _TFT_RASET
	call SPI0_Send_CMD	
	CLRW				; offset h 0x00
	call SPI0_Send_DTA
	CLRW				; offset l 0x00
	call SPI0_Send_DTA
	CLRW				; height h 0x00
	call SPI0_Send_DTA
	movlw 0x7F			; height ; 0x7F = 128 pixels high
	call SPI0_Send_DTA

	; clear RAM
	CLRF ClearColor
	CLRF ClearColor+1
	CLRF ClearColor+2	
	call SPI0_Fill
	
	; turn display on
	movlw _TFT_DISPON
	call SPI0_Send_CMD	
	

	
	
	
	

spt	
	CLRF ClearColor
	CLRF ClearColor+1
	CLRF ClearColor+2	
	call SPI0_Fill
	
	movlw 0xFF
	movwf ClearColor
	CLRF ClearColor+1
	CLRF ClearColor+2	
	call SPI0_Fill	
	
	CLRF ClearColor
	movlw 0xFF
	movwf ClearColor+1
	CLRF ClearColor+2	
	call SPI0_Fill		
	
	CLRF ClearColor
	CLRF ClearColor+1
	movlw 0xFF
	movwf ClearColor+2	
	call SPI0_Fill		
	
	movlw 0xFF
	movwf ClearColor
	movwf ClearColor+1
	movwf ClearColor+2	
	call SPI0_Fill	
	
	
	;goto spt
	
	
	; init flash
	BSF _SPI1_RST
	
	CLRF CurrentImage
	CLRF SPI1_Bytes_to_Read+1 ;h not used
	
	MOVLW 0x01
	MOVWF SPI1_Bytes_to_Read
	MOVLW SSR
	MOVWF FSR
	MOVLW _W25_Read_SSR
	call SPI1_CMD	
	
	MOVLW 0x03
	MOVWF SPI1_Bytes_to_Read
	MOVLW ID
	MOVWF FSR
	MOVLW _W25_read_JEDEC
	call SPI1_CMD
	
		;show some data
	MOVLW D2
	MOVWF FSR 
	
	MOVLW 0x00
	MOVWF D2
	call disp_byte
	MOVLW 0xFF
	MOVWF D2
	call disp_byte	
	
	MOVLW 0x55
	MOVWF D2
	call disp_byte
	MOVLW 0xAA
	MOVWF D2
	call disp_byte	

	MOVLW SSR
	MOVWF FSR 
	call disp_byte
	
	MOVLW ID
	MOVWF FSR 
	call disp_byte
	INCF FSR, F 
	call disp_byte	
	INCF FSR, F 
	call disp_byte	
	
	
	CLRF CurrentAddress	;Address 00 00 00
	CLRF CurrentAddress+1
	CLRF CurrentAddress+2	
	MOVLW 0x05
	MOVWF SPI1_Bytes_to_Read
	MOVLW ColMod
	MOVWF FSR
	call SPI1_Read		
	
	
	MOVLW ColMod
	MOVWF FSR 
	call disp_byte	;colmod
	INCF FSR, F 
	call disp_byte	;madctl
	INCF FSR, F 
	call disp_byte	;num_Image
	
	INCF FSR, F 
	call disp_byte	;bytes per image 0
	INCF FSR, F 
	call disp_byte	;bytes per image 1
	
	;MOVF BytesPerImages, W
	;MOVWF SPI1_Bytes_to_Read	
	;MOVF BytesPerImages+1, W
	;MOVWF SPI1_Bytes_to_Read+1
	;call SPI1_Transfer	
	
	
e	GOTO e ;end of program stall
	
	
	
	
	
	
SPI1_TX_BYTE ;write 1 byte to SPI1, taking byte in W, using SPI_Buffer
	MOVWF SPI_Buffer	
	BSF STATUS, C	; ensure marker of at least 1 bit will be set in data buffer
	RLF	SPI_Buffer, F ; put MSB of buffer in C and marker in buffer	
spi1_TX_loop		; "clk down-latch-clk up-hold" - loop
	bcf _SPI1_CLK	
	BCF _SPI1_DTAO	; pre-clear output pin
	BTFSC STATUS, C ; check bit to send
	BSF _SPI1_DTAO 	; if C is 1, set output pin	
	BCF STATUS, C	; clear C
	RLF SPI_Buffer, F	; put next bit in C, and a 0 in buffer	
	bsf _SPI1_CLK	
	MOVF SPI_Buffer, F; eval content of buffer in STATUS
	BTFSS STATUS, Z ; leave loop if all bits have been replaced by 0 from C, and initial 1 flag got back into C
	GOTO spi1_TX_loop	
	RETURN
	
	
	
SPI1_RX_BYTE ;read 1 byte from SPI1, writing it in INDF referenced by FSR, uses D1 loop
	CLRF INDF 		; clear destination
	movlw 0x08
	movwf d1	
spi1_RX_loop	
	bcf _SPI1_CLK	; trig clock
	bsf _SPI1_CLK		
	BTFSC _SPI1_DTAI; Chech if data input is different than 0 already in INDF
	BSF STATUS, C	; Set C to 1
	RLF INDF, F		; load C to INDF, send either 0 or end flag to C
	DECFSZ d1, F
	GOTO spi1_RX_loop
	RETURN
	
	
	
SPI1_CMD ; send command and read result, command in W, result in INDF/FSR, uses D1Loop and SPI_Buffer
	BCF _SPI1_CS
	
	call SPI1_TX_BYTE

	MOVF SPI1_Bytes_to_Read, F ;test file content
	BTFSC STATUS, Z
	GOTO spI1_CMD_End 	;skip if nothing to read	
	
SPI1_CMD_RD	
	call SPI1_RX_BYTE
	
	INCF FSR, F ;next byte address
	DECFSZ SPI1_Bytes_to_Read, F
	GOTO SPI1_CMD_RD
		
spI1_CMD_End	
	BSF _SPI1_CS		
	RETURN	
	
	
	
	
	
	
SPI1_Read	; send read command and read data, result in INDF/FSR, uses D1Loop and SPI_Buffer, address in currentAddress, bytes to read in sp1_bytes_to_read
	BCF _SPI1_CS
	
	MOVLW _W25_Read		;command
	CALL SPI1_TX_Byte
	
	MOVF CurrentAddress+2, W ; A2
	CALL SPI1_TX_Byte
	MOVF CurrentAddress+1, W ; A1
	CALL SPI1_TX_Byte
	MOVF CurrentAddress, W   ; A0
	CALL SPI1_TX_Byte

SPI1_RD_RD	
	CALL SPI1_RX_Byte	
	
	INCF FSR, F ;next byte address
	DECFSZ SPI1_Bytes_to_Read, F
	GOTO SPI1_RD_RD
		
	BSF _SPI1_CS		
	RETURN	
	

d120ms	; delay 120ms : header + d1loops * (d1 overhead + (d2loops * (d2 delay)))
	clrf d1
	clrf d2
	;header : 4
l1
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	decfsz d2, f
	goto l1	;loop d2 : 4 / cycles, = 1024 op
	decfsz d1, f
	goto l1	;loop d1 overhead = 3 
	
	RETURN
	

	
SPI0_Send_CMD
	BCF _SPI0_A0
	GOTO SPI0_TX_BYTE
	
SPI0_Send_DTA	
	BSF _SPI0_A0

SPI0_TX_BYTE
	MOVWF SPI_Buffer	; byte to send in internal buffer
	BCF _SPI0_CS	
	
	BCF _SPI0_CLK	
	BCF _SPI0_DTA
	BTFSC SPI_Buffer, 7
	BSF _SPI0_DTA 
	bsf _SPI0_CLK	


	BCF _SPI0_CLK	
	BCF _SPI0_DTA
	BTFSC SPI_Buffer, 6
	BSF _SPI0_DTA 
	bsf _SPI0_CLK	


	BCF _SPI0_CLK	
	BCF _SPI0_DTA
	BTFSC SPI_Buffer, 5
	BSF _SPI0_DTA 
	bsf _SPI0_CLK	


	BCF _SPI0_CLK	
	BCF _SPI0_DTA
	BTFSC SPI_Buffer, 4
	BSF _SPI0_DTA 
	bsf _SPI0_CLK	

	BCF _SPI0_CLK	
	BCF _SPI0_DTA
	BTFSC SPI_Buffer, 3
	BSF _SPI0_DTA 
	bsf _SPI0_CLK	


	BCF _SPI0_CLK	
	BCF _SPI0_DTA
	BTFSC SPI_Buffer, 2
	BSF _SPI0_DTA 
	bsf _SPI0_CLK	


	BCF _SPI0_CLK	
	BCF _SPI0_DTA
	BTFSC SPI_Buffer, 1
	BSF _SPI0_DTA 
	bsf _SPI0_CLK	


	BCF _SPI0_CLK	
	BCF _SPI0_DTA
	BTFSC SPI_Buffer, 0
	BSF _SPI0_DTA 
	bsf _SPI0_CLK		
	nop
	bsf _SPI0_CS		
	RETURN
	
	
	
SPI0_Fill	; send 160 * 128 * RGB(ClearColor)
	movlw _TFT_RAMWR
	call SPI0_Send_CMD	
	
	movlw 0xA0
	movwf d1
	movlw 0x80
	movwf d2

s0fl	;SPI 0 Fill Loop
	movf ClearColor, W	;R
	call SPI0_Send_DTA
	movf ClearColor+1, W;G
	call SPI0_Send_DTA
	movf ClearColor+2, W;B
	call SPI0_Send_DTA
	
	decfsz d1, F	;EOL
	goto s0fl	
	movlw 0xA0
	movwf d1	
	decfsz d2, F	;EOF
	goto s0fl	

	return
	
	
disp_byte
	call mark_red
	movlw 0x08
	movwf d1
s_ssr	
	RLF INDF, F
	BTFSC STATUS, C
	goto s_ssrS
	call mark_black
	goto s_ssrE
s_ssrS	
	call mark_white
s_ssrE	
	decfsz d1, F
	goto s_ssr
	
	return
	
	
mark_red	
	movlw 0xFF
	call SPI0_Send_DTA
	movlw 0x00
	call SPI0_Send_DTA	
	movlw 0x00
	call SPI0_Send_DTA	
	movlw 0xFF
	call SPI0_Send_DTA
	movlw 0x00
	call SPI0_Send_DTA	
	movlw 0x00
	call SPI0_Send_DTA	
	return
mark_white
	movlw 0x80
	call SPI0_Send_DTA
	movlw 0x80
	call SPI0_Send_DTA	
	movlw 0x80
	call SPI0_Send_DTA	
	movlw 0xFF
	call SPI0_Send_DTA
	movlw 0xFF
	call SPI0_Send_DTA	
	movlw 0xFF
	call SPI0_Send_DTA	
	return
mark_black
	movlw 0x80
	call SPI0_Send_DTA
	movlw 0x80
	call SPI0_Send_DTA	
	movlw 0x80
	call SPI0_Send_DTA	
	movlw 0x00
	call SPI0_Send_DTA
	movlw 0x00
	call SPI0_Send_DTA	
	movlw 0x00
	call SPI0_Send_DTA	
	return	
	
	
	
	END
	
	

	
	
	