
;#############################################################################
;	Altitude display
;#############################################################################

MAIN_ALT:
	WRITE_NIXIE_L	4, _char_column
	WRITE_NIXIE_L	1, _char_A

	MOVLW	_index_Alt
	CALL	READ_NEXT		; wait and read CSV data at index 8
	BW_False	Draw_No_alt

	IFDEF	SERIAL_DEBUG
	WRITE_SERIAL_FITOA	data_buffer
	WRITE_SERIAL_FITOA	data_buffer + 1
	WRITE_SERIAL_FITOA	data_buffer + 2
	WRITE_SERIAL_FITOA	data_buffer + 3
	WRITE_SERIAL_FITOA	data_buffer + 4
	WRITE_SERIAL_FITOA	data_buffer + 5
	WRITE_SERIAL_FITOA	data_buffer + 6
	WRITE_SERIAL_FITOA	data_buffer + 7
	WRITE_SERIAL_FITOA	data_buffer + 8
	WRITE_SERIAL_FITOA	data_buffer + 9
	WRITE_SERIAL_L		' '
	ENDIF

	WRITE_SERIAL_F		data_unit
	WRITE_SERIAL_L		' '

	CMP_lf	'M', data_unit
	BR_EQ	MAIN_ALT_Meter
	CMP_lf	'F', data_unit
	BR_EQ	MAIN_ALT_Feet
	GOTO	MAIN_ALT_draw

MAIN_ALT_Meter:			; received unit is Meter
	BTFSS	AU_Select
	GOTO	MAIN_ALT_Meter_format	; if requested unit is meter check range and draw

	WRITE_SERIAL_L		'>'
	WRITE_SERIAL_L		'F'
	WRITE_SERIAL_L		' '
	; else convert to feet
	; 3.281ft / m
	; F = M * 33 / 10 (good enough...)

	CALL	Conv_Str_to_Int	; convert data_buffer string to int in D88_Denum

	WRITE_SERIAL_L	'i'
	MOVc	D88_Denum, IntToConvert
	CALL	WriteHexShort

	FAR_CALL	MULT33s ; D88_Num = D88_Denum * 33

	WRITE_SERIAL_L	'x'
	MOVc	D88_Num, IntToConvert
	CALL	WriteHexColor

	CALL	ColorToBCD
	CALL	ExpandBCD_trimLeft
	WRITE_SERIAL_L	'B'
	MOVi	BCD_Result, IntToConvert
	CALL	WriteHexInteger

	;call feet format routine
	GOTO	MAIN_ALT_Feet_format

MAIN_ALT_Meter_format:
	WRITE_NIXIE_L	3, _char_M

	CMP_lf	CONV_MINUS, data_buffer	; check if negative
	BR_NE	MAIN_ALT_Meter_format_pos

	CMP_lf	CONV_DOT, data_buffer + 1	; impossible dot at buffer[1] "-.0000F"
	BR_EQ	MAIN_ALT_draw
	CMP_lf	CONV_DOT, data_buffer + 2	; dot at buffer[2] "-0.000F"
	BR_EQ	MAIN_ALT_draw
	CMP_lf	CONV_DOT, data_buffer + 3	; dot at buffer[3] "-00.00F"
	BR_EQ	MAIN_ALT_draw
	CMP_lf	CONV_DOT, data_buffer + 4 	; dot at buffer[4] "-000.0F"
	BR_EQ	MAIN_ALT_draw

	STR	data_buffer + 4, FSR	; buffer[4]
	GOTO	MAIN_ALT_Meter_format_2

MAIN_ALT_Meter_format_pos:
	CMP_lf	CONV_DOT, data_buffer		; impossible dot at buffer[0] ".0000F"
	BR_EQ	MAIN_ALT_draw
	CMP_lf	CONV_DOT, data_buffer + 1	; dot at buffer[1] "0.000F"
	BR_EQ	MAIN_ALT_draw
	CMP_lf	CONV_DOT, data_buffer + 2	; dot at buffer[2] "00.00F"
	BR_EQ	MAIN_ALT_draw
	CMP_lf	CONV_DOT, data_buffer + 3	; dot at buffer[3] "000.0F"
	BR_EQ	MAIN_ALT_draw

	; ALT > 999.9 remove decimal
	STR	data_buffer + 3, FSR	; buffer[3]

MAIN_ALT_Meter_format_2:
	INCF	FSR, F
	CMP_lf	END_MARKER, INDF
	BR_EQ	Draw_No_alt
	CMP_lf	CONV_DOT, INDF
	BR_NE	MAIN_ALT_Meter_format_2

	STR	END_MARKER, INDF	;replace dot with end_marker
	GOTO	MAIN_ALT_draw

MAIN_ALT_Feet:				; received unit is Feet
	BTFSC	AU_Select		; if requested unit is feet draw
	GOTO	MAIN_ALT_Feet_format
	;convert to meter
	;*100
	;/33
	WRITE_SERIAL_L		'>'
	WRITE_SERIAL_L		'M'
	WRITE_SERIAL_L		' '

	CALL	Conv_Str_to_Int	; convert data_buffer string to int in D88_Denum

	WRITE_SERIAL_L	'i'
	MOVc	D88_Denum, IntToConvert
	CALL	WriteHexShort

	FAR_CALL	MULT100s	; D88_Num = D88_Denum * 100

	WRITE_SERIAL_L	'x'
	MOVc	D88_Num, IntToConvert
	CALL	WriteHexColor

	FAR_CALL	DIV33c		; D88_Fract = D88_Num / 33, D88_Num = D88_Num % 33

	WRITE_SERIAL_L	'/'
	MOVc	D88_Fract, IntToConvert
	CALL	WriteHexColor

	CALL	ColorToBCD
	WRITE_SERIAL_L	'B'
	MOVi	BCD_Result, IntToConvert
	CALL	WriteHexInteger

	;call meter format routine
	GOTO	MAIN_ALT_Meter_format

MAIN_ALT_Feet_format:
	WRITE_NIXIE_L	3, _char_F
	STR	data_buffer - 1, FSR	; buffer[-1]

MAIN_ALT_Feet_format2:
	INCF	FSR, F
	CMP_lf	END_MARKER, INDF
	BR_EQ	Draw_No_alt
	CMP_lf	CONV_DOT, INDF
	BR_NE	MAIN_ALT_Feet_format2

	STR	END_MARKER, INDF	;replace dot with end_marker
	GOTO	MAIN_ALT_draw

MAIN_ALT_draw:
	STR	9, NixieTube
	MOVLW	data_buffer
	MOVWF	FSR

MAIN_ALT_1:				; seek end of buffer
	CMP_lf	END_MARKER, INDF
	BR_EQ	MAIN_ALT_2
	INCF	FSR, F
	GOTO	MAIN_ALT_1

MAIN_ALT_2:
	DECF	FSR, F
	MOV	INDF, NixieData	; load char
	CMP_lf	CONV_DOT, NixieData	; convert special char ','
	BR_NE	MAIN_ALT_3a
	STR	_char_comma, NixieData

MAIN_ALT_3a:
	CMP_lf	CONV_MINUS, NixieData	; convert special char '-'
	BR_NE	MAIN_ALT_3b
	STR	_char_minus, NixieData
	STR	4, NixieTube
	CALL	Nixie_ClearTube ;remove ":" and replace by '-'
	STR	data_buffer, FSR; short circuit out of loop when encountering a '-'
MAIN_ALT_3b:
	MOV	FSR, TZ_offset	;push FSR
	CALL	Nixie_DrawNum
	MOV	TZ_offset, FSR	;pop FSR

	DECF	NixieTube, F
	CMP_lf	data_buffer, FSR
	BR_EQ	ErrorCheck1
	GOTO	MAIN_ALT_2

Draw_No_alt:
	CALL 	WAIT_DATA

	WRITE_SERIAL_L	'N'
	WRITE_SERIAL_L	'A'

	GOTO	ErrorCheck1



;#############################################################################
;	Latitude display
;#############################################################################

MAIN_LAT:
	MOVLW	_index_Lat
	CALL	READ_NEXT		; wait and read CSV data at index 3
	BW_False	Draw_No_Lat

	IFDEF	SERIAL_DEBUG
	WRITE_SERIAL_FITOA	data_buffer
	WRITE_SERIAL_FITOA	data_buffer + 1
	WRITE_SERIAL_FITOA	data_buffer + 2
	WRITE_SERIAL_FITOA	data_buffer + 3
	WRITE_SERIAL_FITOA	data_buffer + 4
	WRITE_SERIAL_FITOA	data_buffer + 5
	WRITE_SERIAL_FITOA	data_buffer + 6
	WRITE_SERIAL_FITOA	data_buffer + 7
	WRITE_SERIAL_FITOA	data_buffer + 8
	WRITE_SERIAL_FITOA	data_buffer + 9
	WRITE_SERIAL_FITOA	data_buffer + 10
	WRITE_SERIAL_FITOA	data_buffer + 11
	WRITE_SERIAL_FITOA	data_buffer + 12
	WRITE_SERIAL_L		' '
	ENDIF

	WRITE_SERIAL_F		data_unit
	WRITE_SERIAL_L		' '

	; direction
	CMP_lf	'N', data_unit
	BR_EQ	MAIN_LAT_1N
	CMP_lf	'S', data_unit
	BR_EQ	MAIN_LAT_1S
	GOTO	MAIN_LAT_2
MAIN_LAT_1N:
	WRITE_NIXIE_L	0, _char_plus
	GOTO	MAIN_LAT_2
MAIN_LAT_1S:
	WRITE_NIXIE_L	0, _char_minus
MAIN_LAT_2:
	; ,4538.12345,N,
	;degrees
	; dont draw if 0
	CMP_lf	0, data_latD10
	BR_EQ	MAIN_LAT_2a
	WRITE_NIXIE_F	2, data_latD10

MAIN_LAT_2a:
	WRITE_NIXIE_F	3, data_latD01
	WRITE_NIXIE_L	4, _char_dot

	;fraction
	; 4538.10504,N
	; max to int 5 999 999 -> 24bit (color)
	;(mm + mmfraction_to_int) / 60
	MOVLW	data_latM10
	CALL	Conv_Str_to_Fract

	WRITE_SERIAL_L	'i'
	MOVc	D88_Denum, IntToConvert
	CALL	WriteHexColor

	FAR_CALL	DIV60c		; D88_Fract = D88_Num / 60, D88_Num = D88_Num % 60

	WRITE_SERIAL_L	'/'
	MOVc	D88_Fract, IntToConvert
	CALL	WriteHexColor

	CALL	ColorToBCD
	WRITE_SERIAL_L	'B'
	MOVi	BCD_Result, IntToConvert
	CALL	WriteHexInteger

	WRITE_NIXIE_F	5, data_buffer + 3
	WRITE_NIXIE_F	6, data_buffer + 4
	WRITE_NIXIE_F	7, data_buffer + 5
	WRITE_NIXIE_F	8, data_buffer + 6
	WRITE_NIXIE_F	9, data_buffer + 8 ; 7 is dot

	GOTO	ErrorCheck1

Draw_No_Lat:
	CALL 	WAIT_DATA

	WRITE_SERIAL_L	'N'
	WRITE_SERIAL_L	'L'
	WRITE_SERIAL_L	'A'
	WRITE_SERIAL_L	'T'

	GOTO	ErrorCheck1



;#############################################################################
;	Longitude display
;#############################################################################

MAIN_LONG:
	MOVLW	_index_Long
	CALL	READ_NEXT		; wait and read CSV data at index 1
	BW_False	Draw_No_Long

	IFDEF	SERIAL_DEBUG
	WRITE_SERIAL_FITOA	data_buffer
	WRITE_SERIAL_FITOA	data_buffer + 1
	WRITE_SERIAL_FITOA	data_buffer + 2
	WRITE_SERIAL_FITOA	data_buffer + 3
	WRITE_SERIAL_FITOA	data_buffer + 4
	WRITE_SERIAL_FITOA	data_buffer + 5
	WRITE_SERIAL_FITOA	data_buffer + 6
	WRITE_SERIAL_FITOA	data_buffer + 7
	WRITE_SERIAL_FITOA	data_buffer + 8
	WRITE_SERIAL_FITOA	data_buffer + 9
	WRITE_SERIAL_FITOA	data_buffer + 10
	WRITE_SERIAL_FITOA	data_buffer + 11
	WRITE_SERIAL_FITOA	data_buffer + 12
	WRITE_SERIAL_L		' '
	ENDIF

	WRITE_SERIAL_F		data_unit
	WRITE_SERIAL_L		' '

	; direction
	CMP_lf	'E', data_unit
	BR_EQ	MAIN_LONG_1E
	CMP_lf	'W', data_unit
	BR_EQ	MAIN_LONG_1W
	GOTO	MAIN_LONG_2
MAIN_LONG_1E:
	WRITE_NIXIE_L	0, _char_plus
	GOTO	MAIN_LONG_2
MAIN_LONG_1W:
	WRITE_NIXIE_L	0, _char_minus

MAIN_LONG_2:
	; ,07318.12345,W,
	;degrees
	; dont draw if 0
	CMP_lf	0, data_longD100
	BR_EQ	MAIN_LONG_2a
	WRITE_NIXIE_F	1, data_longD100

MAIN_LONG_2a:
	CMP_lf	0, data_longD010
	BR_EQ	MAIN_LONG_2b
	WRITE_NIXIE_F	2, data_longD010
MAIN_LONG_2b:
	WRITE_NIXIE_F	3, data_longD001
	WRITE_NIXIE_L	4, _char_dot

	;fraction
	; 4538.10504,N
	; max to int 5 999 999 -> 24bit (color)
	;(mm + mmfraction_to_int) / 60

	MOVLW	data_longM10
	CALL	Conv_Str_to_Fract

	WRITE_SERIAL_L	'i'
	MOVc	D88_Denum, IntToConvert
	CALL	WriteHexColor

	FAR_CALL	DIV60c		; D88_Fract = D88_Num / 60, D88_Num = D88_Num % 60

	WRITE_SERIAL_L	'/'
	MOVc	D88_Fract, IntToConvert
	CALL	WriteHexColor

	CALL	ColorToBCD
	WRITE_SERIAL_L	'B'
	MOVi	BCD_Result, IntToConvert
	CALL	WriteHexInteger

	WRITE_NIXIE_F	5, data_buffer + 3
	WRITE_NIXIE_F	6, data_buffer + 4
	WRITE_NIXIE_F	7, data_buffer + 5
	WRITE_NIXIE_F	8, data_buffer + 6
	WRITE_NIXIE_F	9, data_buffer + 8 ; 7 is dot

	GOTO	ErrorCheck1

Draw_No_Long:
	CALL 	WAIT_DATA

	WRITE_SERIAL_L	'N'
	WRITE_SERIAL_L	'L'
	WRITE_SERIAL_L	'O'
	WRITE_SERIAL_L	'N'
	WRITE_SERIAL_L	'G'

	GOTO	ErrorCheck1






;#############################################################################
;	Nixie Tube Serial (74x595) 10 tubes X 9 segments
;#############################################################################

; light up all segments
Nixie_All: ;()[NixieLoop]
	MOVLW	NixieBuffer
	MOVWF	FSR
	STR	10, NixieLoop
Nixie_All_Next:
	CLRF	INDF
	INCF	FSR, F
	DECFSZ	NixieLoop, F
	GOTO	Nixie_All_Next
	RETURN

; Turn all segments off
Nixie_None: ;()[NixieLoop]
	MOVLW	NixieBuffer
	MOVWF	FSR
	STR	10, NixieLoop
	MOVLW	0xFF
Nixie_None_Next:
	MOVWF	INDF
	INCF	FSR, F
	DECFSZ	NixieLoop, F
	GOTO	Nixie_None_Next
	RETURN

; Turn off all segments of 1 tube
Nixie_ClearTube: ;(NixieTube)[NixieLoop, WriteLoop, NixieVarX, NixieVarY]
	MOVF	NixieTube, W
	CALL	Nixie_MaxSeg	; get number of segments for the tube
	MOVWF	NixieLoop

	MOVF	NixieTube, W
	CALL	Nixie_Offsets	; get the bit offset for that tube
	MOVWF	NixieVarX	; offset, will be lost each write
	MOVWF	WriteLoop	; offset to keep original value

Nixie_ClearTube_Loop:
	CLRF	NixieVarY	; to receive remainder
	BCF	STATUS, C	; div and mod bit number to get byte and bit offsets
	RRF	NixieVarX, F	; / 2
	RRF	NixieVarY, F
	BCF	STATUS, C
	RRF	NixieVarX, F	; / 4
	RRF	NixieVarY, F
	BCF	STATUS, C
	RRF	NixieVarX, F	; / 8
	RRF	NixieVarY, F
	BCF	STATUS, C	; shift modulo 1 more time to align with nibble
	RRF	NixieVarY, F
	SWAPF	NixieVarY, F

	MOVLW	NixieBuffer	; @data
	ADDWF	NixieVarX, W	; + byte offset
	MOVWF	FSR		; FSR = @data[di]
	BSet	INDF, 	NixieVarY ; Y = bit offset

	INCF	WriteLoop, F
	MOV	WriteLoop, NixieVarX	;next segment in X
	DECFSZ	NixieLoop, F
	GOTO	Nixie_ClearTube_Loop
	RETURN

; light up 1 segment, seg# in NixieSeg, tube# in NixieTube
Nixie_SetSegment: ;(NixieSeg, NixieTube)[NixieVarX, NixieVarY]

	MOVLW	high (TABLE0)
	MOVWF	PCLATH

	MOVF	NixieTube, W
	CALL	Nixie_MaxSeg	; get number of segments for the tube
	SUBWF	NixieSeg, W	; w = seg# - max, borrow should be set (carry cleared)
	BTFSC	STATUS, C
	RETURN

	MOVF	NixieTube, W
	CALL	Nixie_Offsets	; get the bit offset for that tube
	ADDWF	NixieSeg, W	; NixieVarX = offset + seg#
	MOVWF	NixieVarX

	CLRF	NixieVarY	; to receive remainder
	BCF	STATUS, C
	RRF	NixieVarX, F	; / 2
	RRF	NixieVarY, F
	BCF	STATUS, C
	RRF	NixieVarX, F	; / 4
	RRF	NixieVarY, F
	BCF	STATUS, C
	RRF	NixieVarX, F	; / 8
	RRF	NixieVarY, F
	BCF	STATUS, C	; shift modulo 1 more time to align with nibble
	RRF	NixieVarY, F
	SWAPF	NixieVarY, F

	MOVLW	NixieBuffer	; @data
	ADDWF	NixieVarX, W
	MOVWF	FSR		; FSR = @data[di]
	BClear	INDF, 	NixieVarY
	RETURN

; Draw a num [0-9], char code in NixieData, tube in NixieTube
Nixie_DrawNum:	;(NixieData) [NixieLoop]
; CALL	Nixie_SetSegment:(NixieSeg, NixieTube)[NixieVarX, NixieVarY]

	MOVLW	high (TABLE0)
	MOVWF	PCLATH
	MOVF	NixieData, W
	CALL	Nixie_Num_seg8
	MOVWF	NixieLoop

	STR	8, NixieSeg
	BTFSC	NixieLoop, 0 ; test seg 8
	CALL	Nixie_SetSegment

	MOVF	NixieData, W
	CALL	Nixie_Num_seg0_7
	MOVWF	NixieLoop

Nixie_DrawNum_loop:
	DECF	NixieSeg, F
	RLF	NixieLoop, F
	BTFSC	STATUS, C
	CALL	Nixie_SetSegment
	INCF	NixieSeg, F
	DECFSZ	NixieSeg, F
	GOTO	Nixie_DrawNum_loop

	RETURN

;Send the data to the SIPO buffers, LSBit of LSByte first
Nixie_Send: ;()[WriteLoop, NixieLoop]

	MOVLW	NixieBuffer
	MOVWF	FSR
	STR	10, WriteLoop
Nixie_Send_Next_Byte:
	STR	8, NixieLoop

Nixie_Send_Next_Bit:
	BCF	NixieSerial_Data
	RRF	INDF, F
	BTFSC	STATUS, C
	BSF	NixieSerial_Data

	BSF	NixieSerial_Clock
	BCF	NixieSerial_Clock

	DECFSZ	NixieLoop, F
	GOTO	Nixie_Send_Next_Bit

	INCF	FSR, F
	DECFSZ	WriteLoop, F
	GOTO	Nixie_Send_Next_Byte

	BSF	NixieSerial_Latch
	BCF	NixieSerial_Latch

	RETURN


