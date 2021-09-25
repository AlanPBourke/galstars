;
; galenciastars.bas
;
; By Alan Bourke in 2021 using XC-BASIC 2.3
;
; This is a conversion of Jason Aldred's Galencia starfield, taken from his
; game of the same name. Jason extracted the starfield ASM code into a standalone
; programme (see link below), and this is an XC-BASIC recreation of that.
; 
; I wanted to see if an XC-BASIC version could approach the speed of the ASM and 
; in an eyeball test at least, it does. I've commented the code quite heavily to 
; maybe help other people in tasks like redefining the char set and so on.
;
; I briefly worked in the same dev house as Jason in the early 90s, and he was
; always ready to help other coders. I know he's had his health problems so if he 
; ever reads this, I hope he's OK.
;
; Useful Links
;
; Jason Aldred's original Galencia starfield extracted to a standalone program.
; https://github.com/Jimmy2x2x/C64-Starfield/blob/master/starfield.asm
;
; Info about the C64 character set.
; https://github.com/neilsf/XC-BASIC/tree/master/examples/invaders
; https://www.c64-wiki.com/wiki/Character_set
;
; Info about the C64 memory map.
; https://www.pagetable.com/c64ref/c64mem/
; https://github.com/Project-64/reloaded/blob/master/c64/mapc64/MAPC6412.TXT
;
; GRay Defender's breakdown of how the original ASM works - WATCH THIS.
; https://www.youtube.com/watch?v=47LakVkR5lg&t=1251s


; Star shapes
const Star1Shape    = %00000011  ; 3
const Star2Shape    = %00001100  ; 12
const Star3Shape    = %00110000  ; 48
const Star4Shape    = %11000000  ; 192

const SCREEN        = $0400
const COLOUR        = $D800
const BORDER        = $D020
const BACKGR        = $D021
const CHAR_ROM       = $D000
const CHAR_RAM      = $3000
const NUMCHARS      = $0800 ; 256 chars x 8 bytes each 

const VIC_CTRL      = $D018
const CPU_IO        = $0001
const SCRN_CTRL     = $D011
const RASTERLINE    = $D012

const Star1Init     = $31D0 ; Init address for each star, CHAR_RAM plus offset
const Star1Limit    = $3298 ; Limit for each star
const Star1Reset    = $31d0 ; Reset address for each star

const Star2Init     = $3298
const Star2Limit    = $3360 ; Once limit is reached, they are reset
const Star2Reset    = $3298

const Star3Init     = $3240
const Star3Limit    = $3298
const Star3Reset    = $31d0

const Star4Init     = $32E0
const Star4Limit    = $3360
const Star4Reset    = $3298

const StaticStar1   = $3250 ; 2 Locations for blinking static stars
const StaticStar2   = $31e0

dim RasterCount!    fast 
dim StarfieldPtr    fast
dim StarfieldPtr2   fast
dim StarfieldPtr3   fast
dim StarfieldPtr4   fast 
dim Blinkflag!      fast

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
                                                            ; Ignoring the rightmost bit, we have 110 = decimal 6, so 6 x 2048 = 12288 
                                                            ; which in hex is the location $3000 where our copy of the character set is.
	
    enableirq                                               ; Interrupts back on.

    memset \CHAR_RAM, 2048, 0                               ; Clear user defined character set.
                                                            ; Comment this line out to see the result of the CreateStarScreen 
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
                char! = 83                                    ; If we've gone past character 107 then back to 83.
            endif  
			
            poke \COLOUR + offset, ~						
                \StarfieldColours![colourindex!]            ; The colours of the C64 character screen are defined by the 1000 locations from $D800
                                                            ; onwards, each location corresponding to a location on the character screen at $0400
                                                            ; So we put the current colour from the colour array into the colour location corresponding
                                                            ; to the current row and column on the text screen.
            inc row

        until row = 23
	  
        inc colourindex!                                    ; Next column, next colour.	
	
        if colourindex! > 19 then
            colourindex! = 0
        endif
	
        inc col!
	
    until col! = 39
	
    poke \SCRN_CTRL, peek(\SCRN_CTRL) | %00010000           ; Turn the screen back on.
  
	; poke 198,0: wait 198, 1                               ; If uncommented this waits for a keypress.
	
endproc

; ------------------------------------------------------------------------------------------------------------------------------------
; Main routine.
; ------------------------------------------------------------------------------------------------------------------------------------
start:
  
    poke \BORDER, 0                                         ; Black screen background and border.
    poke \BACKGR, 0
  
    CopyCharsetToRam                                        ; Copy the ROM character set to RAM.									

    CreateStarScreen                                        ; Set up the initial screen.
  
    \RasterCount!   = 0
    \Blinkflag!     = 1
    \StarfieldPtr   = \Star1Init
    \StarfieldPtr2  = \Star2Init
    \StarfieldPtr3  = \Star3Init
    \StarfieldPtr4  = \Star4Init

    goto loop
	
loop:
  
    watch \RASTERLINE, 255                                  ; Wait for raster to be offscreen. We do our drawing at that point 
                                                            ; to avoid flicker.
  
    inc \RasterCount!                                       ; A counter controlling which group of stars is redrawn, i.e. 
                                                            ; this implements the different star speeds. Will automatically wrap 255 to 0 
	
    gosub DoStarfield                                       ; Draw the stars.
	
    goto loop
	
DoStarfield:
  
    on \Blinkflag! gosub BlinkOne, BlinkTheOther            ; Handle the static blinking stars.

    poke StarfieldPtr,0                                     ; Clear any existing stars by zeroing their memory location
    poke StarfieldPtr2,0                                    
    poke StarfieldPtr3,0
    poke StarfieldPtr4,0
  
    ; Star 1 -----------------------------------------------
    if (\RasterCount! & 1) = 1 then
        
        inc \StarfieldPtr                                   ; Star 1 updates every other frame.
        poke \StarfieldPtr, peek(StarfieldPtr) | Star1Shape  	   
        
        if \StarfieldPtr = \Star1Limit then
            \StarfieldPtr = \Star1Reset
        endif
    
    else
        poke \StarfieldPtr, peek(StarfieldPtr) | Star1Shape		   
    endif 

    ; Star 2 -----------------------------------------------
    inc \StarfieldPtr2                                      ; Star 2 updates every frame.
    poke \StarfieldPtr2, peek(StarfieldPtr2) | Star2Shape	  
    if \StarfieldPtr2 = Star2Limit then
        \StarfieldPtr2 = \Star2Reset
    endif

    ; Star 3 -----------------------------------------------
    if (\RasterCount! & 1) = 1 then
        inc \StarfieldPtr3                                      ; Star 3 updates every other frame.
        poke \StarfieldPtr3, peek(StarfieldPtr3) | Star3Shape	
        if \StarfieldPtr3 = \Star3Limit then
            \StarfieldPtr3 = \Star3Reset
        endif
    else
        poke \StarfieldPtr3, peek(StarfieldPtr3) | Star3Shape
    endif	  

    ; Star 4 -----------------------------------------------
    inc \StarfieldPtr4                                        ; Star 4 updates 2 pixels every frame.
    inc \StarfieldPtr4
    poke \StarfieldPtr4, peek(StarfieldPtr4) | Star4Shape
    poke \StarfieldPtr4 - 2, 0
    if \StarfieldPtr4 = \Star4Limit then
        \StarfieldPtr4 = \Star4Reset
    endif
	  
    return

BlinkOne:
	
    if \RasterCount! < 231 then
        poke \StaticStar1, peek(StaticStar1) | 192
    else
        poke \StaticStar1, 0
    endif	 

    \Blinkflag! = 0

  return	
	  
BlinkTheOther:

    if \RasterCount! < 231 then
        poke \StaticStar2, peek(StaticStar2) | 192
    else
        poke \StaticStar2, 0
    endif  

    \Blinkflag! = 1

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

					   
