lorom

; Replace the instruction to refill health

org $848972
	inc $0A06 ;} Increment previous health to queue HUD redraw
