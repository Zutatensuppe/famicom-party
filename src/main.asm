.include "constants.inc"
.include "header.inc"

.segment "ZEROPAGE"
player_x: .res 1
player_y: .res 1
player_dir: .res 1
player_speed: .res 1

scroll_y: .res 1
ppuctrl_settings: .res 1

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
  DEC scroll_y
  LDA scroll_y
  STA PPUSCROLL ; scroll Y

  RTI
.endproc

.import reset_handler

.import draw_starfield
.import draw_objects

.export main
.proc main
  ; set the initial scroll to 239 (max vertical scroll)
  LDA #239
  STA scroll_y

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


.proc update_player
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; -----------------------------------
  ; VERTICAL MOVEMENT
  DEC player_y
  ; if player_y > e0 set it to e0
  LDA #$e0
  CMP player_y
  BCS not_out_of_screen_y
  STA player_y
not_out_of_screen_y:

  ; -----------------------------------
  ; HORIZONTAL MOVEMENT
  LDA player_x
  CMP #$e0
  BCC not_at_right_edge
  ; if BCC is not taken, we are greater than $e0
  LDA #$00
  STA player_dir ; start moving left
  JMP direction_set ; we already chose a direction, so skip the left side check

not_at_right_edge:
  LDA player_x
  CMP #$10
  BCS direction_set
  ; if BCS not taken, we are less than $10
  LDA #$01
  STA player_dir ; start moving right

direction_set:
  ; now actually update the player_x
  LDA player_dir
  CMP #$01
  BEQ move_right
  
  LDA player_x
  SEC
  SBC player_speed
  STA player_x

  JMP exit_subroutine

move_right:
  LDA player_x
  CLC
  ADC player_speed
  STA player_x

exit_subroutine:

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
