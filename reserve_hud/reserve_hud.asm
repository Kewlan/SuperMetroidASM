; New Reserve HUD Style

lorom

!samus_max_reserves = $7E09D4
!samus_reserves = $7E09D6
!base_tile = #$2060

; Static variables
tile_data = $10
right_tile = $12
healthCheck_Lower = $14
healthCheck_Upper = $16
special_helper = $18
special_tile_loc = $7EF500 ; 16 bytes of the special tile

org $82AF36
    NOP #4
    NOP #4
    NOP #4
    NOP #4

org $809B4E
    JMP $CDA0

org $80CDA0
    LDA $09C0   ; Load Reserve Mode
    BNE CONTINUE  ; If Not obtained
    JMP RETURN
CONTINUE:
    CMP #$0001  ; If Auto
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
    ; LDA special_tile_loc : CLC : ADC #$0001 : STA special_tile_loc ; TEST
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
FCST_PARTIAL_FILL_BAR:
    ; TODO
FCST_FUNCTION_DMA_SPECIAL_TILE:
    LDX $7E0330
    LDA #$0010 : STA $7E00D0,x ; Number of bytes
    LDA #$0000 : STA $7E00D2,x ;\
    LDA #$7EF5 : STA $7E00D3,x ;}Source address
    LDA #$4350 : STA $7E00D5,x ; Destination in Vram
    TXA : CLC : ADC #$0007 : STA $7E0330 ; Update the stack pointer
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
