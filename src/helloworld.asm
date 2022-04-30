.include "constants.inc"
.include "header.inc"

.segment "ZEROPAGE"
player_x: .res 1
player_y: .res 1
player_dir: .res 1
player_speed: .res 1

moon_x: .res 1
moon_y: .res 1
.exportzp player_x, player_y, player_speed

.segment "RODATA"
palettes:
.byte $0f, $12, $23, $27
.byte $0f, $2b, $3c, $39
.byte $0f, $0c, $07, $13
.byte $0f, $19, $09, $29

.byte $0f, $12, $23, $27
.byte $0f, $2b, $3c, $39
.byte $0f, $0c, $07, $13
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

  ; moon
  JSR update_moon
  JSR draw_moon

  ; update tiles *after* DMA transfer
  JSR update_player
  JSR draw_player

  LDA #$00
  STA PPUSCROLL
  STA PPUSCROLL

  RTI
.endproc

.import reset_handler

.export main
.proc main
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

  LDA #$40
  STA moon_x
  STA moon_y

  ; write a nametable
  ; big stars first
  LDX #$2f  ; big star index in sprite table

  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$6b
  STA PPUADDR
  STX PPUDATA

  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$ba
  STA PPUADDR
  STX PPUDATA

  LDA PPUSTATUS
  LDA #$21
  STA PPUADDR
  LDA #$65
  STA PPUADDR
  STX PPUDATA

  LDA PPUSTATUS
  LDA #$22
  STA PPUADDR
  LDA #$66
  STA PPUADDR
  STX PPUDATA

  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$0e
  STA PPUADDR
  STX PPUDATA


  ; VERY big star
  LDA PPUSTATUS
  LDA #$22
  STA PPUADDR
  LDA #$54
  STA PPUADDR
  LDX #$29
  STX PPUDATA

  LDA PPUSTATUS
  LDA #$22
  STA PPUADDR
  LDA #$55
  STA PPUADDR
  LDX #$2a
  STX PPUDATA

  LDA PPUSTATUS
  LDA #$22
  STA PPUADDR
  LDA #$74
  STA PPUADDR
  LDX #$2b
  STX PPUDATA

  LDA PPUSTATUS
  LDA #$22
  STA PPUADDR
  LDA #$75
  STA PPUADDR
  LDX #$2c
  STX PPUDATA


vblankwait: ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000 ; turn on NMIs, sprites use first pattern table
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

.proc update_moon
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; move the moon somehow
  LDA player_x
  CMP #$40
  BCC smaller_than_40
  INC moon_x
  JMP end_update_moon
smaller_than_40:
  DEC moon_x
  INC moon_y
end_update_moon:
  ; all done

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP

  RTS
.endproc

.proc draw_moon
  ; save registers
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; OFFSET in oam buffer
  LDX #$10
  LDA moon_y
  PHA
  LDA moon_x
  PHA

  ; write player ship tile numbers
  LDA #$30
  STA $0201,X
  LDA #$31
  STA $0205,X
  LDA #$32
  STA $0209,X
  LDA #$33
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
.incbin "starfield.chr"
