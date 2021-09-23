rem https://github.com/Jimmy2x2x/C64-Starfield/blob/master/starfield.asm
rem https://github.com/neilsf/XC-BASIC/tree/master/examples/invaders
rem https://www.c64-wiki.com/wiki/Character_set

rem https://www.pagetable.com/c64ref/c64mem/

; include "xcb-ext-rasterinterrupt.bas"

const SCREEN      = $0400
const COLOR       = $D800
const BORDER      = $D020
const BACKGR      = $D021
const CHARBASE    = $3000
const NUMCHARS    = $0800 ; 256 chars x 8 bytes each
const VIC_CTRL    = $D018
const CPU_IO      = $0001
const SCRN_CTRL   = $D011
const STAR1INIT   = $31D0 ; Init address for each star, CHARBASE plus offset
const STAR2INIT   = $3298
const STAR3INIT   = $3240
const STAR4INIT   = $32E0

const STAR1LIMIT  = $3298 ; Limit for each star
const STAR2LIMIT  = $3360 ; Once limit is reached, they are reset
const STAR3LIMIT  = $3298
const STAR4LIMIT  = $3360

dim counter fast

goto start

; ------------------------------------------------------------------------------------------------------------------------------------
; Copy the ROM character set to RAM so that it can be redefined, and point the VIC-II at it.
; ------------------------------------------------------------------------------------------------------------------------------------
proc copy_charset_to_ram
  
  disableirq
  
  poke \CPU_IO, (peek(\CPU_IO) & %11111011)               ; The '0' in bit 2 switches the character generator ROM in 
                                                          ; so that it can be read.
  memcpy $D800, \CHARBASE, \NUMCHARS                      ; Copy entire ROM character set to RAM at $3000.
  poke \CPU_IO, (peek(\CPU_IO) | %0100)                   ; Switch I\O back in instead of char gen ROM.
  poke \VIC_CTRL, (peek(\VIC_CTRL) & %11110000) | %1100   ; Point VIC-II control register at mapped characters.
  
  enableirq

endproc

; ------------------------------------------------------------------------------------------------------------------------------------
; Initial screen setup.
; ------------------------------------------------------------------------------------------------------------------------------------
proc CreateStarScreen

  poke 53272,21
  char! = 0
  colourindex! = 0
  offset = 0
  
  poke \SCRN_CTRL, peek(\SCRN_CTRL) & %11101111    ; Screen off
  
  for col! = 0 to 39
	
    char! = \StarfieldRow![col!] 
	
    for row = 0 to 24

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

    next 
      
    inc colourindex!
    if colourindex! > 19 then
      colourindex! = 0
    endif
    
  next 
	
  poke \SCRN_CTRL, peek(\SCRN_CTRL) | %00010000    ; Screen on
  
  ; poke 198,0: wait 198, 1
	
endproc

; ------------------------------------------------------------------------------------------------------------------------------------
; Business end of things.
; ------------------------------------------------------------------------------------------------------------------------------------
start:
  
  poke BORDER, 0                                         ; Black screen background and border.
  poke BACKGR, 0
  
  copy_charset_to_ram                                     

  memset \SCREEN, 1000, 32                                ; Clear screen with spaces.
  
  CreateStarScreen
  
  end
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

                       
