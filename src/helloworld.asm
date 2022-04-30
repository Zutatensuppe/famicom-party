.include "constants.inc"
.include "header.inc"

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
sprites:
;     Y-pos          X-pos
.byte $70, $05, $00, $80 ; 1st tile
.byte $70, $06, $00, $88 ; 2nd tile
.byte $78, $07, $00, $80 ; 3rd tile
.byte $78, $08, $00, $88 ; 4th tile

.segment "CODE"
.proc irq_handler
  RTI
.endproc

.proc nmi_handler
  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA

  ; TODO: use a constant for $2005
  LDA #$00
  STA $2005
  STA $2005

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

  LDX #$00
load_sprites:
  LDA sprites,X
  STA $0200,X
  INX
  CPX #$10
  BNE load_sprites

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


  ; VERY big moon
  LDA PPUSTATUS
  LDA #$21
  STA PPUADDR
  LDA #$48
  STA PPUADDR
  LDX #$30
  STX PPUDATA

  LDA PPUSTATUS
  LDA #$21
  STA PPUADDR
  LDA #$49
  STA PPUADDR
  LDX #$31
  STX PPUDATA

  LDA PPUSTATUS
  LDA #$21
  STA PPUADDR
  LDA #$68
  STA PPUADDR
  LDX #$32
  STX PPUDATA

  LDA PPUSTATUS
  LDA #$21
  STA PPUADDR
  LDA #$69
  STA PPUADDR
  LDX #$33
  STX PPUDATA

  ; attrib table
  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$d2
  STA PPUADDR
  LDX #%00110000
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

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "starfield.chr"
