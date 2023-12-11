; New Reserve HUD Style

lorom

!samus_max_reserves = $09D4
!samus_reserves = $09D6
!samus_previous_reserves = $0A1A ; Previously unused
!base_tile = #$2060

; Variables
tile_data = $10             ; Stores what should be written to the tilemap
right_tile = $12            ; Effectively a bool: If set, draw the right column of the bars
healthCheck_Lower = $14     ; Is compared with reserves and max reserves ...
healthCheck_Upper = $16     ; ... to determine what to draw
special_helper = $18        ; Used to store info to help draw the special tile correct
special_tile_loc = $F500    ; 16 bytes of the special tile

; Don't call broken function
org $82AED9
    NOP #3

; Don't clear reserve tiles
org $82AF36
    NOP #4
    NOP #4
    NOP #4
    NOP #4

org $809B4E
    JMP FUNCTION_DRAW_RESERVE_HUD

org $80CDA0
FUNCTION_DRAW_RESERVE_HUD:
    LDA $09C0
    CMP #$0001
    BNE DRAW_TILES
DRAW_AUTO_TEXT:
    LDA #$3C47  ; AU
    STA $7EC698 ; Bottom left
    LDA #$3C48  ; TO
    STA $7EC69A ; Bottom right
DRAW_TILES:
    ; Bottom left
    LDA #$0000 : STA right_tile
    LDA #$0000 : STA healthCheck_Lower  ; 0
    LDA #$0064 : STA healthCheck_Upper  ; 100
    JSR FUNCTION_DRAW_TILE
    STA $7EC658
    ; Bottom right
    LDA #$0001 : STA right_tile
    LDA #$0032 : STA healthCheck_Lower  ; 50
    LDA #$0096 : STA healthCheck_Upper  ; 150
    JSR FUNCTION_DRAW_TILE
    STA $7EC65A
    ; Top left
    LDA #$0000 : STA right_tile
    LDA #$00C8 : STA healthCheck_Lower  ; 200
    LDA #$012C : STA healthCheck_Upper  ; 300
    JSR FUNCTION_DRAW_TILE
    STA $7EC618
    ; Top right
    LDA #$0001 : STA right_tile
    LDA #$00FA : STA healthCheck_Lower  ; 250
    LDA #$015E : STA healthCheck_Upper  ; 350
    JSR FUNCTION_DRAW_TILE
    STA $7EC61A
RETURN:
    ; Return
    JMP $9B8B

; Sets the tile data to the Accumulator
; - right_tile
; - healthCheck_Lower
; - healthCheck_Upper
FUNCTION_DRAW_TILE:
    ; First check if the max reserves even reach this amount
    LDA !samus_max_reserves
    CMP healthCheck_Lower       ; Example: If (100 - 0 > 0) { DRAW! }
    BEQ FDT_RETURN_EMPTY_TILE
    BPL FDT_SPECIAL_TILE_CHECK_LOWER
FDT_RETURN_EMPTY_TILE:
    LDA #$2C0F
    RTS
FDT_SPECIAL_TILE_CHECK_LOWER:
    LDA healthCheck_Lower : CLC : ADC #$0032 : STA special_helper ; special_helper = Lower+50
    LDA !samus_reserves
    CMP healthCheck_Lower
    BEQ FDT_SPECIAL_TILE_CHECK_UPPER : BMI FDT_SPECIAL_TILE_CHECK_UPPER ; if (reserves <= 0) { Continue } else { Check upper limit }
    CMP special_helper
    BPL FDT_SPECIAL_TILE_CHECK_UPPER ; Continue
    BMI FDT_RETURN_SPECIAL_TILE
FDT_SPECIAL_TILE_CHECK_UPPER:
    LDA healthCheck_Upper : CLC : ADC #$0032 : STA special_helper
    LDA !samus_reserves
    CMP healthCheck_Upper
    BEQ FDT_PREPARE_Y : BMI FDT_PREPARE_Y ; Continue
    CMP special_helper
    BPL FDT_PREPARE_Y ; Continue
    BMI FDT_RETURN_SPECIAL_TILE
FDT_RETURN_SPECIAL_TILE:
    ; Return special tile
    JSR FUNCTION_CREATE_SPECIAL_TILE
    LDA !base_tile : CLC : ADC #$000A
    RTS
FDT_PREPARE_Y:
    ; Store current tile offset in Y
    LDY #$0000
    LDA right_tile
    BEQ FDT_CALC_START
    INY
FDT_CALC_START:
    LDA healthCheck_Upper        ;\
    CMP !samus_max_reserves      ;|
    BPL FDT_HAS_HEALTH_FIRST_RESERVE ;|
    INY #4                       ;} If there are at least TWO reserves 
    LDA healthCheck_Upper        ;\
    CMP !samus_reserves          ;|
    BPL FDT_HAS_HEALTH_FIRST_RESERVE ;|
    INY #2                       ;} If the 2nd reserve has ANY health
FDT_HAS_HEALTH_FIRST_RESERVE:
    LDA healthCheck_Lower   ;\
    CMP !samus_reserves     ;|
    BPL FDT_RETURN_TILE         ;|
    INY #2                  ;} If the 1st reserve has ANY health
FDT_RETURN_TILE:
    LDA !base_tile
    STA tile_data
    TYA
    CLC
    ADC tile_data
    RTS

; Creates the sub-tile progress tile in VRAM
FUNCTION_CREATE_SPECIAL_TILE:
    ; TEST: LDA special_tile_loc : CLC : ADC #$0001 : STA special_tile_loc
    ; Step 1: Copy the data of the tile that the special tile should be based on
    LDA #$B800 : STA special_helper
FCST_DECIDE_RIGHT_TILE:
    LDA right_tile
    BEQ FCST_DECIDE_TWO_BARS
    LDA special_helper : CLC : ADC #$0010 : STA special_helper
FCST_DECIDE_TWO_BARS:
    LDA healthCheck_Upper
    CMP !samus_max_reserves
    BPL FCST_MEMCPY
    LDA special_helper : CLC : ADC #$0040 : STA special_helper
FCST_DECIDE_FILL_LOWER_BAR:
    LDA healthCheck_Upper
    CMP !samus_reserves
    BPL FCST_MEMCPY
    LDA special_helper : CLC : ADC #$0020 : STA special_helper
FCST_MEMCPY:
    PHB
    LDA #$000F          ; Copy 16 bytes
    LDX special_helper  ; Source
    LDY #$F500          ; Destination
    MVN $9A7E
    PLB
FCST_PAINT_BAR:
    ; Step 2: Paint over the columns of the bar that should be filled
    ; First change data bank to 7E
    PHB : PEA $7E00 : PLB : PLB
    LDX healthCheck_Upper
    LDY #special_tile_loc
FCST_PAINT_BAR_DECIDE_OFFSET:
    ; When painting top bar, the first 8 bytes are affected
    ; When painting bottom bar, the last 8 bytes are affected
    LDA healthCheck_Upper
    CMP !samus_reserves
    BMI FCST_PAINT_COLUMNS
    INY #8 ; If we reach here, we're painting the bottom bar
    LDX healthCheck_Lower
FCST_PAINT_COLUMNS:
    ; X has health test
    ; Y has address
    LDA right_tile
    BNE FCST_PAINT_COLUMN_0
    ; Draw the unique left side first bar, always
    ; Health > 0
FCST_PAINT_COLUMN_LEFT:
    LDA $0000,y : AND #$BFBF : ORA #$4000 : STA $0000,y
    LDA $0002,y : AND #$BFBF : ORA #$4000 : STA $0002,y
    LDA $0004,y : AND #$BFBF : ORA #$4000 : STA $0004,y
    BRA FCST_PAINT_COLUMN_2
FCST_PAINT_COLUMN_0:
    INX #8 : CPX !samus_reserves : BPL FCST_PAINT_COLUMN_1
    LDA $0000,y : AND #$7F7F : ORA #$8000 : STA $0000,y
    LDA $0002,y : AND #$7F7F : ORA #$0080 : STA $0002,y
    LDA $0004,y : AND #$7F7F : ORA #$0080 : STA $0004,y
FCST_PAINT_COLUMN_1:
    INX #8 : CPX !samus_reserves : BPL FCST_PAINT_COLUMN_2
    LDA $0000,y : AND #$BFBF : ORA #$4000 : STA $0000,y
    LDA $0002,y : AND #$BFBF : ORA #$0040 : STA $0002,y
    LDA $0004,y : AND #$BFBF : ORA #$0040 : STA $0004,y
FCST_PAINT_COLUMN_2:
    INX #8 : CPX !samus_reserves : BPL FCST_PAINT_COLUMN_3
    LDA $0000,y : AND #$DFDF : ORA #$2000 : STA $0000,y
    LDA $0002,y : AND #$DFDF : ORA #$0020 : STA $0002,y
    LDA $0004,y : AND #$DFDF : ORA #$0020 : STA $0004,y
FCST_PAINT_COLUMN_3:
    INX #8 : CPX !samus_reserves : BPL FCST_PAINT_COLUMN_4
    LDA $0000,y : AND #$EFEF : ORA #$1000 : STA $0000,y
    LDA $0002,y : AND #$EFEF : ORA #$0010 : STA $0002,y
    LDA $0004,y : AND #$EFEF : ORA #$0010 : STA $0004,y
FCST_PAINT_COLUMN_4:
    INX #8 : CPX !samus_reserves : BPL FCST_PAINT_COLUMN_5
    LDA $0000,y : AND #$F7F7 : ORA #$0800 : STA $0000,y
    LDA $0002,y : AND #$F7F7 : ORA #$0008 : STA $0002,y
    LDA $0004,y : AND #$F7F7 : ORA #$0008 : STA $0004,y
    LDA right_tile : BEQ FCST_PAINT_COLUMN_5 ; Right side tiles stop here
    JMP FCST_DMA_SPECIAL_TILE
FCST_PAINT_COLUMN_5:
    INX #8 : CPX !samus_reserves : BPL FCST_PAINT_COLUMN_6
    LDA $0000,y : AND #$FBFB : ORA #$0400 : STA $0000,y
    LDA $0002,y : AND #$FBFB : ORA #$0004 : STA $0002,y
    LDA $0004,y : AND #$FBFB : ORA #$0004 : STA $0004,y
FCST_PAINT_COLUMN_6:
    INX #8 : CPX !samus_reserves : BPL FCST_PAINT_COLUMN_7
    LDA $0000,y : AND #$FDFD : ORA #$0200 : STA $0000,y
    LDA $0002,y : AND #$FDFD : ORA #$0002 : STA $0002,y
    LDA $0004,y : AND #$FDFD : ORA #$0002 : STA $0004,y
FCST_PAINT_COLUMN_7:
    INX #8 : CPX !samus_reserves : BPL FCST_DMA_SPECIAL_TILE
    LDA $0000,y : AND #$FEFE : ORA #$0100 : STA $0000,y
    LDA $0002,y : AND #$FEFE : ORA #$0001 : STA $0002,y
    LDA $0004,y : AND #$FEFE : ORA #$0001 : STA $0004,y
FCST_DMA_SPECIAL_TILE:
    ; Step 3: Get the data over to the VRAM
    LDX $0330
    LDA #$0010 : STA $00D0,x ; Number of bytes
    LDA #$0000 : STA $00D2,x ;\
    LDA #$7EF5 : STA $00D3,x ;}Source address
    LDA #$4350 : STA $00D5,x ; Destination in Vram
    TXA : CLC : ADC #$0007 : STA $0330 ; Update the stack pointer
    PLB ; Restore data bank
    RTS



; NEW TILES

; Row 6, Column 0       
org $9AB800
    db $00, $00, $00, $00, $00, $00, $00, $00, $7F, $7F, $40, $7F, $40, $7F, $00, $00 ; One Reserve | Empty | Left
    db $00, $00, $00, $00, $00, $00, $00, $00, $FC, $FC, $00, $FC, $00, $FC, $00, $00 ; One Reserve | Empty | Right
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $7F, $3F, $40, $3F, $40, $00, $00 ; One Reserve | Full | Left
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $FC, $FC, $00, $FC, $00, $00, $00 ; One Reserve | Full | Right
    db $7F, $7F, $40, $7F, $40, $7F, $00, $00, $7F, $7F, $40, $7F, $40, $7F, $00, $00 ; Two Reserve | Empty/Empty | Left
    db $FC, $FC, $00, $FC, $00, $FC, $00, $00, $FC, $FC, $00, $FC, $00, $FC, $00, $00 ; Two Reserve | Empty/Empty | Right
    db $7F, $7F, $40, $7F, $40, $7F, $00, $00, $00, $7F, $3F, $40, $3F, $40, $00, $00 ; Two Reserve | Full/Empty | Left
    db $FC, $FC, $00, $FC, $00, $FC, $00, $00, $00, $FC, $FC, $00, $FC, $00, $00, $00 ; Two Reserve | Full/Empty | Right
    db $00, $7F, $3F, $40, $3F, $40, $00, $00, $00, $7F, $3F, $40, $3F, $40, $00, $00 ; Two Reserve | Full/Full | Left
    db $00, $FC, $FC, $00, $FC, $00, $00, $00, $00, $FC, $FC, $00, $FC, $00, $00, $00 ; Two Reserve | Full/Full | Right
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Special Tile
