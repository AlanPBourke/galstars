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
const COLOUR      = $D800
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

dim rastercount! 	fast 
dim starfieldPtr 	fast
dim starfieldPtr2 	fast
dim starfieldPtr3 	fast
dim starfieldPtr4 	fast 
dim blinkflag! 		fast

\starfieldPtr    = $31d0
\starfieldPtr2   = $3298
\starfieldPtr3   = $3240
\starfieldPtr4   = $32e0

goto start

; ------------------------------------------------------------------------------------------------------------------------------------
; This routine copies the C64 character set from ROM into RAM, allowing it to then be redefined..
; ------------------------------------------------------------------------------------------------------------------------------------
proc CopyCharsetToRam
  
	disableirq                                              ; Turn off interrupts from the keyboard etc.
  
	poke \CPU_IO, (peek(\CPU_IO) & %11111011)               ; The '0' in bit 2 tells the CPU to stop looking at I\O
                                                            ; and to start looking at the character set in ROM so that it can be read.

	memcpy \CHAR_ROM, \CHAR_RAM, \NUMCHARS                  ; Copy the 2KB ROM character set to RAM starting at location $3000.
 
	poke \CPU_IO, (peek(\CPU_IO) | %0100)                   ; Switch I\O back in instead of character set in ROM.
	
	poke \VIC_CTRL, (peek(\VIC_CTRL) & %11110000) | %1100   ; Tell the VIC-II to from now on look at location $3000 for the character set. 
															; This is controlled by bits 1, 2 and 3 of location $D018 (VIC_CTRL)
															; counting from right to left. Those three bits represent a number which
															; when multiplied by 2048 gives the memory location where the character set 
															; starts.
															; Looking at the 'poke' above, we are ORing with the binary value 1100
															; Ignoring the rightmost bit, we have 110 = decimal 6 x 2048 = 12288 which
															; in hex is our location $3000.
	
	enableirq                                               ; Interrupts back on.

	;memset \CHAR_RAM, 2048, 0                              ; Clear user defined character set.
                                                            ; Uncomment this line to see the result of the CreateStarScreen 
                                                            ; routine below.
	
endproc

; ------------------------------------------------------------------------------------------------------------------------------------
; Initial screen setup.
; 
; This routine draws columns of characters onto the C64 text screen. 
; ------------------------------------------------------------------------------------------------------------------------------------
proc CreateStarScreen

	char! = 0
	colourindex! = 0
	offset = 0
  
	poke \SCRN_CTRL, peek(\SCRN_CTRL) & %11101111           ; Turn the screen off for speed and tidiness.
  
	col! = 0
	repeat                                                  ; C64 character text screen has 40 columns.
	
		char! = \StarfieldRow![col!]                        ; Get the next character number from the StarfieldRow array. The first one is character 58 
                                                            ; which is a ':'.
	
		row = 0                                             ; C64 character text screen has 25 rows.
		repeat

			offset = (col! + (row * 40))                    ; The text screen can be though of as a grid. however in memory 
                                                            ; it starts at location $0400 and is comprised of 1000 memory locations.
                                                            ; Given a row and column this calculation gives the offset from the start of screen memory 
                                                            ; to the location we want.
															
			poke \SCREEN + offset, char!                    ; Stick the current character onto the screen at the current row and column.
	  
			inc char!                                       ; Point at the next char in the array.
	  
			if char! = 83 then
				char! = 58                                  ; If we've gone past character 83 then start again.
			endif
	  
			if char! = 108 then								
				char! = 83                                  ; If we've gone past character 107 then start again.
			endif  
			
			poke \COLOUR + offset, ~						
				\StarfieldColours![colourindex!]            ; The colours of the C64 character screen are defined by the 1000 locations from $D800
															; onwards, each location corresponding to a location on the character screen at $0400
															; So we put the current colour from the colour array into the colour location corresponding
															; to the current row and column on the text screen.
			inc row

		until row = 23
	  
		inc colourindex!									; Next column, next colour.	
	
		if colourindex! > 19 then
			colourindex! = 0
		endif
	
		inc col!
	
	until col! = 39
	
	poke \SCRN_CTRL, peek(\SCRN_CTRL) | %00010000    		; Turn the screen back on.
  
	; poke 198,0: wait 198, 1								; This waits for a keypress.
	
endproc

; ------------------------------------------------------------------------------------------------------------------------------------
; Main routine.
; ------------------------------------------------------------------------------------------------------------------------------------
start:
  
	poke \BORDER, 0                                         ; Black screen background and border.
	poke \BACKGR, 0
  
	CopyCharsetToRam 										; Copy the ROM character set to RAM.                                    

	CreateStarScreen										; Set up the initial screen.
  
	\rastercount! = 0
	\blinkflag! = 1
	goto loop
	
loop:
  
	watch \RASTERLINE, 255          						; Wait for raster to be offscreen. We do our drawing at that point 
															; to avoid flicker.
  
	inc \rastercount!               						; A counter controlling which group of stars is redrawn, i.e. 
															; this implements the different star speeds. Will automatically wrap 255 to 0 
	
	gosub DoStarfield										; Draw the stars.
	
	goto loop
	
DoStarfield:
  
  
  on \blinkflag! gosub BlinkOne, BlinkTheOther				; Handle the static blinking stars.

  poke starfieldPtr,0
  poke starfieldPtr2,0
  poke starfieldPtr3,0
  poke starfieldPtr4,0
  
  
  if (\rastercount! & 1) = 1 then
	inc \starfieldPtr										; Star 1 draws every other frame.
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

BlinkOne:
	
  if \rastercount! < 231 then
	  poke \staticStar1, peek(staticStar1) | 192
  else
	  poke \staticStar1, 0
  endif  

  \blinkflag! = 0

  return    
	  
BlinkTheOther:

	if \rastercount! < 231 then
		poke \staticStar2, peek(staticStar2) | 192
	else
		poke \staticStar2, 0
	endif  

	\blinkflag! = 1

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

					   
