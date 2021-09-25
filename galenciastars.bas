rem https://github.com/Jimmy2x2x/C64-Starfield/blob/master/starfield.asm
rem https://github.com/neilsf/XC-BASIC/tree/master/examples/invaders
rem https://www.c64-wiki.com/wiki/Character_set

rem https://www.pagetable.com/c64ref/c64mem/
rem https://github.com/Project-64/reloaded/blob/master/c64/mapc64/MAPC6412.TXT

; poke 53272, 21
; 21 is 0001 0101
; bits 1-3 = 010 = decimal 2 so character data is 2 x 1024 = 2048 bytes from start of VIC memory
; 
;
; Star shapes
const Star1Shape = %00000011  ; 3
const Star2Shape = %00001100  ; 12
const Star3Shape = %00110000  ; 48
const Star4Shape = %11000000  ; 192
;
; include "xcb-ext-rasterinterrupt.bas"

const SCREEN      = $0400
const COLOR       = $D800
const BORDER      = $D020
const BACKGR      = $D021
const CHAR_ROM    = $D000
const CHAR_RAM    = $3000
const NUMCHARS    = $0800 ; 256 chars x 8 bytes each 

const VIC_CTRL    = $D018
const CPU_IO      = $0001
const SCRN_CTRL   = $D011
const RASTERLINE  = $D012

const STAR1INIT   = $31D0 ; Init address for each star, CHAR_RAM plus offset
const STAR1LIMIT  = $3298 ; Limit for each star
const star1Reset  = $31d0 ; Reset address for each star

const STAR2INIT   = $3298
const STAR2LIMIT  = $3360 ; Once limit is reached, they are reset
const star2Reset  = $3298

const STAR3INIT   = $3240
const STAR3LIMIT  = $3298
const star3Reset  = $31d0

const STAR4INIT   = $32E0
const STAR4LIMIT  = $3360
const star4Reset  = $3298

const staticStar1 = $3250 ; 2 Locations for blinking static stars
const staticStar2 = $31e0

dim rastercount! fast 
dim starfieldPtr fast
dim starfieldPtr2 fast
dim starfieldPtr3 fast
dim starfieldPtr4 fast 

\starfieldPtr    = $31d0
\starfieldPtr2   = $3298
\starfieldPtr3   = $3240
\starfieldPtr4   = $32e0
\zeroPointer     = $f8

goto start

; ------------------------------------------------------------------------------------------------------------------------------------
; Copy the ROM character set to RAM so that it can be redefined, and point the VIC-II at it.
; ------------------------------------------------------------------------------------------------------------------------------------
proc copy_charset_to_ram
  
  disableirq
  
  poke \CPU_IO, (peek(\CPU_IO) & %11111011)               ; The '0' in bit 2 switches the character generator ROM in 
                                                          ; so that it can be read.
  memcpy \CHAR_ROM, \CHAR_RAM, \NUMCHARS                      ; Copy entire ROM character set to RAM at $3000.
 
  poke \CPU_IO, (peek(\CPU_IO) | %0100)                   ; Switch I\O back in instead of char gen ROM.
  poke \VIC_CTRL, (peek(\VIC_CTRL) & %11110000) | %1100   ; Point VIC-II control register at mapped characters.
 
  enableirq

endproc

; ------------------------------------------------------------------------------------------------------------------------------------
; Initial screen setup.
; ------------------------------------------------------------------------------------------------------------------------------------
proc CreateStarScreen

  ;poke 53272,21
  char! = 0
  colourindex! = 0
  offset = 0
  
  poke \SCRN_CTRL, peek(\SCRN_CTRL) & %11101111    ; Screen off
  
  col! = 0
  repeat
	
    char! = \StarfieldRow![col!] 
	
    row = 0
    repeat

      ;charat col!, row!, char!
      offset = (col! + (row * 40))
      poke \SCREEN + offset, char!
      
      inc char!
	  
      if char! = 83 then
        char! = 58      
      endif
	  
      if char! = 108 then
        char! = 83
      endif  

      poke \COLOR + offset, \StarfieldColours![colourindex!]

      inc row

    until row = 23
      
    inc colourindex!
    if colourindex! > 19 then
      colourindex! = 0
    endif
    
    inc col!
    
  until col! = 39
	
  poke \SCRN_CTRL, peek(\SCRN_CTRL) | %00010000    ; Screen on
  
  ; poke 198,0: wait 198, 1
	
endproc

; ------------------------------------------------------------------------------------------------------------------------------------
; Business end of things.
; ------------------------------------------------------------------------------------------------------------------------------------
start:
  
  poke \BORDER, 0                                         ; Black screen background and border.
  poke \BACKGR, 0
  
  copy_charset_to_ram                                     

  ;memset \CHAR_RAM, 2048, 0                              ; Clear user defined character set
  
  CreateStarScreen
  
  \rastercount! = 0
  
loop:
  
;  asm "
;@loop
; lda #$ff                        ; Wait for raster to be off screen
;@wait
; cmp $d012
; bne @wait
;     "
  
  watch \RASTERLINE, 255          ; Wait for raster to be offscreen.
  
  inc \rastercount!               ; Will automatically wrap 255 to 0 
  gosub DoStarfield
  goto loop
    
DoStarfield:
  
      ; Static flickering stars.
      if \rastercount! < 231 then
        poke \staticStar1, peek(staticStar1) | 192
        poke \staticStar2, peek(staticStar2) | 192
      else
        poke \staticStar1, 0
        poke \staticStar2, 0
      endif  
  
      poke starfieldPtr,0
      poke starfieldPtr2,0
      poke starfieldPtr3,0
      poke starfieldPtr4,0
      
      ; -- Every other frame
      if (\rastercount! & 1) = 1 then
        inc \starfieldPtr
        poke \starfieldPtr, peek(starfieldPtr) | Star1Shape    
        ;poke \starfieldPtr-1, 0
        if \starfieldPtr = \STAR1LIMIT then
          \starfieldPtr = \STAR1INIT
        endif
      else
        poke \starfieldPtr, peek(starfieldPtr) | Star1Shape        
      endif 

      ; one pixel per frame
      inc \starfieldPtr2
      poke \starfieldPtr2, peek(starfieldPtr2) | Star2Shape   
      ;poke \starfieldPtr2-1, 0
      if \starfieldPtr2 = \STAR2LIMIT then
        \starfieldPtr2 = \star2Reset
      endif
  
      ; -- Every other frame
      if (\rastercount! & 1) = 1 then
        inc \starfieldPtr3
        poke \starfieldPtr3, peek(starfieldPtr3) | Star3Shape   
;        poke \starfieldPtr-1, 0
        if \starfieldPtr3 = \STAR3LIMIT then
           \starfieldPtr3 = \star3Reset
        endif
      else
        poke \starfieldPtr3, peek(starfieldPtr3) | Star3Shape
      endif   
  
      ; two pixels per frame
      inc \starfieldPtr4
      inc \starfieldPtr4
      poke \starfieldPtr4, peek(starfieldPtr4) | Star4Shape
      poke \starfieldPtr4-2, 0
      if \starfieldPtr4 = \STAR4LIMIT then
        \starfieldPtr4 = \star4Reset
      endif
      
  return

  DoStar2:

      ; One per frame
      inc \starfieldPtr2
      poke \starfieldPtr2, peek(starfieldPtr2) | 12
        
  return
      
; ------------------------------------------------------------------------------------------------------------------------------------
; Data declarations.
; ------------------------------------------------------------------------------------------------------------------------------------ 

; These are character indexes, not screen codes.
; 058 is a ':', 077 is a '\' 
data StarfieldRow![] = ~
058,092,073,064,091,062,093,081,066,094, ~
086,059,079,087,080,071,076,067,082,095, ~
100,078,099,060,075,063,084,065,083,096, ~
068,088,074,061,090,098,085,101,097,077

data StarfieldColours![] = ~
14,10,12,15,14,13,12,11,10,14, ~
14,10,14,15,14,13,12,11,10,12

                       
