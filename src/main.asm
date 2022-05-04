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

; 4 bullets (y/x positions)
bullets: .res 8

; 4 enemies (y/x/hp positions)
enemies: .res 12

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
  JSR update_enemies
  JSR update_player

  JSR do_collision_detection

  ; update tiles *after* DMA transfer
  JSR draw_bullets
  JSR draw_player
  JSR draw_enemies

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

  JSR init_enemies

  JSR init_bullets

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

  ; update visible bullets
  LDX #$00
update_single_cannon:
  LDA bullets,X
  CMP #$e0
  BCS movement_finished
  SBC #3
  STA bullets,X
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

.proc update_enemies
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; move the enemy to the right
  LDX #$01
  LDA enemies,X
  ADC #01
  STA enemies,X

  ; check enemy hp
  INX
  LDA enemies,X
  BNE exit_subroutine
  ; respawn
  JSR init_enemies
exit_subroutine:

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
  LDA bullets,X
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
  STA bullets,X
  LDA player_x
  ADC #$03
  INX
  STA bullets,X

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


.proc init_bullets
  ; initialize bullets
  ; this means hide them off screen
  ; (setting y = $fe)
  LDX #$00
next_bullet:
  LDA #$fe 
  STA bullets,X
  INX
  INX
  CPX #$08
  BNE next_bullet
  RTS
.endproc

.proc init_enemies
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; initialize enemies
  LDX #$00
  LDA #40
  STA enemies,X
  INX
  LDA #40
  STA enemies,X
  INX
  LDA #10
  STA enemies,X
  INX

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP

  RTS
.endproc

; ---------------------------------------------


;
; Check collision between Bullet X and Enemy Y
;
.proc collision_check
  ; X = BULLET index
  ; Y = ENEMY index

  ; no collision:
  ; if bullet.y + 8 < enemy.y: no col
  ; if bullet.y - 8 > enemy.y: no col
  ; if bullet.x + 8 < enemy.x: no col
  ; if bullet.x - 8 > enemy.x: no col
  ; else col


; check collision Y
  ; if canon.y + 8 < enemy.y: no col
  LDA bullets,X        ; canon.y + 8
  ADC #8
  CMP enemies,Y        ; enemy.y
  BCC exit_subroutine

  ; if canon.y - 8 > enemy.y: no col
  LDA bullets,X        ; canon.y - 8
  SBC #8
  CMP enemies,Y        ; enemy.y
  BCS exit_subroutine

; when there was a collision on Y
; do the check collision X
  INX

  INY
  LDA bullets,X       
  ADC #8              ; bullet.x + 8
  CMP enemies,Y       ; enemy.x
  BCC exit_subroutine

  LDA bullets,X
  SBC #8              ; bullet.x - 8
  CMP enemies,Y       ; enemy.x
  BCS exit_subroutine

; collision detected!

  ; move bullet out of screen
  DEX
  LDA #$f0
  STA bullets,X
  INX

  ; decrease the enemy HP if not already 0
  INY
  LDA enemies,Y
  CMP #0
  BEQ exit_subroutine
  SBC #1
  STA enemies,Y

exit_subroutine:

  RTS
.endproc


.proc do_collision_detection
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDX #00
  LDY #00
  JSR collision_check
  
  LDX #02
  LDY #00
  JSR collision_check

  LDX #04
  LDY #00
  JSR collision_check

  LDX #06
  LDY #00
  JSR collision_check


  PLA
  TAY
  PLA
  TAX
  PLA
  PLP

  RTS
.endproc


; ---------------------------------------------



.proc draw_bullets
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDY #0
  LDX #0
next_entity:
  LDA bullets,X
  STA $0210,Y
  INY
  LDA #$09
  STA $0210,Y
  INY
  LDA #$00
  STA $0210,Y
  INY
  INX
  LDA bullets,X
  STA $0210,Y
  INY
  INX
  CPX #$08
  BNE next_entity

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

.proc draw_enemies
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDY #0
  LDX #0
next_entity:
  LDA #$f0
  STA $0220,Y
  
  ;; check hp
  INX
  INX
  LDA enemies,X
  BEQ exit_subroutine
  DEX
  DEX


  LDA enemies,X
  STA $0220,Y
  INX
  INY

  LDA #$0a
  STA $0220,Y
  INY

  ; HP
  INX
  LDA enemies,X
  CMP #$05
  BCS green
red:
  LDA #$00
  JMP do
green:
  LDA #$01
do:
  STA $0220,Y
  DEX
  INY

  LDA enemies,X
  STA $0220,Y
  INY
  INX

  ; CPX #$08
  ; BNE next_entity

exit_subroutine:
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
