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

cooldown: .res 1

; 4 cannons (x/y positions)
cannons: .res 8
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

  LDA #05
  STA cooldown

  ; initialize cannons
  ; this means hide them off screen
  ; (setting y = $fe and x = 0)
  LDX #$00
hide_cannon:
  LDA #$fe 
  STA cannons,X
  INX
  LDA #$00 
  STA cannons,X
  INX
  CPX #$08
  BNE hide_cannon

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

  ; update visible cannons
  LDX #$00
update_single_cannon:
  LDA cannons,X
  CMP #$e0
  BCS movement_finished
  SBC #3
  STA cannons,X
movement_finished:
  INX
  INX
  CPX #$08
  BNE update_single_cannon

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

; if cooldown > 0: cooldown--
  LDA cooldown
  BEQ dont_adjust_cd
  SBC #1
  STA cooldown
dont_adjust_cd:



  ; -----------------------------------
  ; A BUTTON
  LDA buttons
  AND #%10000000
  ; CMP #%10000000
  BEQ after_a
  ; Pressing A

  ; shoot tha cannon!
  ; find a cannon slot that is 
  ; currently not used
  ; we have 4 slots

  LDA cooldown
  BNE after_a
  
  LDX #$00
check_next:
  CPX #$08
  BEQ after_a

  ; load the y coord of the cannon
  LDA cannons,X
  ; if its y coord is > $e0
  CMP #$e0
  BCS use_canon ; CANON is FREE, use it!

  ; canon is not FREE, dont use
  INX
  INX
  JMP check_next

use_canon:
  ; found a good cannon to be shot
  LDA player_y
  STA cannons,X
  LDA player_x
  ADC #$03
  INX
  STA cannons,X

  LDA #05
  STA cooldown

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

  LDY #0
  LDX #0
next_cannon:
  LDA cannons,X
  STA $0210,Y
  INY
  LDA #$09
  STA $0210,Y
  INY
  LDA #$00
  STA $0210,Y
  INY
  INX
  LDA cannons,X
  STA $0210,Y
  INY
  INX
  CPX #$08
  BNE next_cannon

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

  ; write player ship tile numbers
  LDA #$05
  STA $0201
  LDA #$06
  STA $0205
  LDA #$07
  STA $0209
  LDA #$08
  STA $020d

  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  LDA player_x
  STA $0203
  STA $020b
  CLC
  ADC #$08
  STA $0207
  STA $020f

  LDA player_y
  STA $0200
  STA $0204
  CLC
  ADC #$08
  STA $0208
  STA $020c

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
