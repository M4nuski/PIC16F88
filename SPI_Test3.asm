	LIST	p=16F88		;Processor
	#INCLUDE <p16F88.inc>	;Processor Specific Registers
	#INCLUDE <PIC16F88_Macro.asm>
	
	__CONFIG	_CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_OFF & _PWRTE_ON & _WDT_OFF & _HS_OSC
	__CONFIG	_CONFIG2, _IESO_ON & _FCMEN_ON

; Bank #    SFR           GPR               SHARED GPR's
; Bank 0    0x00-0x1F     0x20-0x6F         0x70-0x7F    
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF

; SPI 0 Config
#define _SPI0_CS  PORTB, 0
#define _SPI0_SCK PORTB, 1
#define _SPI0_DTA PORTB, 2
#define _SPI0_A0  PORTB, 3 ; register select / A0 command:0, data:1
#define _SPI0_RST PORTB, 4

; debug status leds
#define _setup_reset PORTA, 2
#define _tft_config  PORTA, 3
#define _tft_data  	 PORTA, 4

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
	
	
; SPI interface GPR

	cblock 0x020
		d1, d2		; loops counters
		SPI0_OUT	; Output buffer for SPI 0
		ClearColor:3; r g b
		;_SPI0_IN
		;_SPI0_LEN_B2
		;_SPI0_LEN_B1
		;_SPI0_LEN_B0
	endc

	
	
	ORG	0x0000
	
	; setup 
	
	BANK0
	BCF	INTCON, GIE	; clear global interrupts

	BANK1
	BSF	OSCCON, IRCF0	; internal OSC setup
	BSF	OSCCON, IRCF1	; 8mhz
	BSF	OSCCON, IRCF2	

	CLRF ANSEL			; all digital IO
	
	; SPI
	bcf _SPI0_CS
	bcf _SPI0_SCK
	bcf _SPI0_DTA
	bcf _SPI0_RST
	bcf _SPI0_A0
	
	; status leds
	BCF _setup_reset
	BCF _tft_config
	BCF _tft_data

	BANK0	
	
	; default state mode 3
	bsf _SPI0_CS
	bsf _SPI0_SCK
	bsf _SPI0_RST
	
	; clear status leds
	bcf _setup_reset
	bcf _tft_config
	bcf _tft_data
	
	; main
	
	; reset TFT	

	BCF _SPI0_RST
	call d120ms	;actual minimum is 10us or 20 ops
	BSF _SPI0_RST
	call d120ms	
	movlw _TFT_SWRESET
	call SPI0_Send_CMD
	call d120ms
	
	BSF _setup_reset ; display reset completed
		
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

	BSF _tft_config	; display config completed
	
	CLRF ClearColor
	CLRF ClearColor+1
	CLRF ClearColor+2	
	call SPI0_Fill
	
	movlw _TFT_DISPON
	call SPI0_Send_CMD	
	
	BSF _tft_data ; display data completed
	
	call d120ms
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
	
	goto spt
	
e	GOTO e ;end of program stall
	
	
	

	

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
	MOVWF SPI0_OUT	; byte to send in internal buffer
	BCF _SPI0_CS	
	BSF STATUS, C	; ensure marker of at least 1 bit will be set in data buffer
	RLF	SPI0_OUT, F ; put MSB of buffer in C and marker in buffer
	
spi0_bit_loop		; "clk down-latch-clk up-hold" - loop
	bcf _SPI0_SCK	
	BCF _SPI0_DTA	; pre-clear output pin
	BTFSC STATUS, C ; check bit to send
	BSF _SPI0_DTA 	; if C is 1, set output pin	
	BCF STATUS, C	; clear C
	RLF SPI0_OUT, F	; put next bit in C, and a 0 in buffer	
	bsf _SPI0_SCK	
	MOVF SPI0_OUT, F; eval content of buffer in STATUS
	BTFSS STATUS, Z ; leave loop if all bits have been replaced by 0 from C, and initial 1 flag got back into C
	GOTO spi0_bit_loop

	bsf _SPI0_CS		
	RETURN
	
	
	
SPI0_Fill	
	movlw _TFT_RAMWR
	call SPI0_Send_CMD	
	
	movlw 0xA0
	movwf d1
	movlw 0x80
	movwf d2

s0fl	
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
	
	
	
	END
	
	

	
	
	