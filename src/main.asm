.include "constants.inc"
.include "header.inc"

.segment "ZEROPAGE"
player_x: .res 1
player_y: .res 1
player_dir: .res 1
player_speed: .res 1

scroll_y: .res 1
;state: .res 1

buttons: .res 1
ppuctrl_settings: .res 1

cannon_1_x: .res 1
cannon_1_y: .res 1

.exportzp player_x, player_y, player_speed

.segment "RODATA"
palettes:
.byte $0f, $12, $23, $27
.byte $0f, $2b, $3c, $39
.byte $0f, $0c, $07, $13
.byte $0f, $19, $09, $29

.byte $0f, $2d, $10, $15
.byte $0f, $19, $09, $29
.byte $0f, $19, $09, $29
.byte $0f, $19, $09, $29

.segment "CODE"
.proc irq_handler
  RTI
.endproc

.proc nmi_handler
  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA

  JSR readjoy

  JSR update_cannon
  JSR draw_cannon

  ; update tiles *after* DMA transfer
  JSR update_player
  JSR draw_player

  ; set the scroll
  LDA scroll_y
  CMP #$00
  BNE set_scroll_positions
  ; if jump is not taken, we have reached 0
  ; and we need to switch nametables
  LDA ppuctrl_settings
  EOR #%00000010 ; flip the 2nd bit
  STA ppuctrl_settings
  STA PPUCTRL
  LDA #240
  STA scroll_y

set_scroll_positions:
  LDA #$00
  STA PPUSCROLL ; scroll X

; SCROLL normal speed
  DEC scroll_y
;----------------------------------

; ; SCROLL twice as fast
;   DEC scroll_y
;   DEC scroll_y
; ;----------------------------------

; ; SCROLL half as fast
;   LDA state
;   CMP #0
;   BNE do_scroll
;   ; state was 0, dont scroll, but store 1 in state
;   LDA #1
;   STA state
;   JMP after_scroll
; do_scroll:
;   DEC scroll_y
;   LDA #0
;   STA state
; after_scroll:
; ; SCROLL half as fast 
; ;----------------------------------


  LDA scroll_y
  STA PPUSCROLL ; scroll Y

  RTI
.endproc

.import reset_handler

.import draw_starfield
.import draw_objects

.proc readjoy
  ; At the same time that we strobe bit 0, we initialize the ring counter
  ; so we're hitting two birds with one stone here
  lda #$01
  ; While the strobe bit is set, buttons will be continuously reloaded.
  ; This means that reading from JOYPAD1 will only return the state of the
  ; first button: button A.
  sta JOYPAD1
  sta buttons
  lsr a        ; now A is 0
  ; By storing 0 into JOYPAD1, the strobe bit is cleared and the reloading stops.
  ; This allows all 8 buttons (newly reloaded) to be read from JOYPAD1.
  sta JOYPAD1
  loop:
    lda JOYPAD1
    lsr a	       ; bit 0 -> Carry
    rol buttons  ; Carry -> bit 0; bit 7 -> Carry
    bcc loop
  rts
.endproc


.export main
.proc main
  ; set the initial scroll to 239 (max vertical scroll)
  LDA #239
  STA scroll_y

  ; 'hide' cannon 1 off screen
  LDA #$e0 
  STA cannon_1_y

  ; write a palette
  LDX PPUSTATUS
  LDX #$3f
  STX PPUADDR
  LDX #$00
  STX PPUADDR
load_palettes:
  LDA palettes,X
  STA PPUDATA
  INX
  CPX #$20
  BNE load_palettes

  LDX #$20
  JSR draw_starfield

  LDX #$28
  JSR draw_starfield

  JSR draw_objects

vblankwait: ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000 ; turn on NMIs, sprites use first pattern table
  STA ppuctrl_settings
  STA PPUCTRL

  LDA #%00011110 ; turn on screen
  STA PPUMASK
forever:
  JMP forever
.endproc


.proc update_cannon
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; if y > $e0: dont update anymore, stay hidden off screen
  LDA cannon_1_y
  CMP #$e0
  BCS movement_finished
  SBC #3
  STA cannon_1_y

movement_finished:

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP

  RTS
.endproc


.proc update_player
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; -----------------------------------
  ; A BUTTON
  LDA buttons
  AND #%10000000
  ; CMP #%10000000
  BEQ after_a
  ; Pressing A

  ; shoot tha cannon!
  LDA player_y
  STA cannon_1_y
  LDA player_x
  ADC #$03
  STA cannon_1_x

after_a:
  
  ; -----------------------------------
  ; B BUTTON
  ; LDA buttons
  ; AND #%01000000
  ; BEQ after_b
  ; ; Pressing A
  ; LDA player_x
  ; ADC #5
  ; STA player_x

after_b:

  ; -----------------------------------
  ; VERTICAL MOVEMENT
  LDA buttons
  AND #%00000100
  BEQ not_pressing_down
  ; Pressing DOWN
  INC player_y
  INC player_y

not_pressing_down:
  LDA buttons
  AND #%00001000
  BEQ after_y_movement
  ; Pressing UP
  DEC player_y
  DEC player_y

after_y_movement:

  ; -----------------------------------
  ; HORIZONTAL MOVEMENT
  LDA buttons
  AND #%00000010
  CMP #%00000010
  BNE not_pressing_left
  ; Pressing LEFT
  DEC player_x
  DEC player_x

not_pressing_left:
  LDA buttons
  AND #%00000001
  CMP #%00000001
  BNE after_x_movement
  ; Pressing RIGHT
  INC player_x
  INC player_x

after_x_movement:

;   ; -----------------------------------
;   ; HORIZONTAL MOVEMENT
;   LDA player_x
;   CMP #$e0
;   BCC not_at_right_edge
;   ; if BCC is not taken, we are greater than $e0
;   LDA #$00
;   STA player_dir ; start moving left
;   JMP direction_set ; we already chose a direction, so skip the left side check

; not_at_right_edge:
;   LDA player_x
;   CMP #$10
;   BCS direction_set
;   ; if BCS not taken, we are less than $10
;   LDA #$01
;   STA player_dir ; start moving right

; direction_set:
;   ; now actually update the player_x
;   LDA player_dir
;   CMP #$01
;   BEQ move_right
  
;   LDA player_x
;   SEC
;   SBC player_speed
;   STA player_x

;   JMP exit_subroutine

; move_right:
;   LDA player_x
;   CLC
;   ADC player_speed
;   STA player_x

; exit_subroutine:

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP

  RTS
.endproc

.proc draw_cannon
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA cannon_1_y
  STA $0210
  LDA #$09
  STA $0211
  LDA #$00
  STA $0212
  LDA cannon_1_x
  STA $0213

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP

  RTS
.endproc


.proc draw_player
  ; save registers
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; OFFSET in oam buffer
  LDX #$00
  LDA player_y
  PHA
  LDA player_x
  PHA

  ; write player ship tile numbers
  LDA #$05
  STA $0201,X
  LDA #$06
  STA $0205,X
  LDA #$07
  STA $0209,X
  LDA #$08
  STA $020d,X

  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202,X
  STA $0206,X
  STA $020a,X
  STA $020e,X

  PLA
  STA $0203,X
  STA $020b,X
  CLC
  ADC #$08
  STA $0207,X
  STA $020f,X

  PLA
  STA $0200,X
  STA $0204,X
  CLC
  ADC #$08
  STA $0208,X
  STA $020c,X

  ; restore registers
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP

  RTS
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "scrolling.chr"
