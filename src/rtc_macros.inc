;----| SUMMARY |--------------------------------------------------------------------------------;
;													 											;
;	Author:			Duluxan Sritharan												 			;
;	Company:		Team 40														 				;
;	Date:			April 14, 2009													 			;
;																							 	;
;	Hardware: 		MicroChip PIC16F877												 			;
;	Assembler:		mpasm.exe														 			;
;																			 					;
;	Filename:		rtc_macros.inc													 			;
;	File Version:	Release														 				;
;	Project Files:	STRG.asm												 		 			;
;					i2c_common.asm													 			;
;																							 	;
;-----------------------------------------------------------------------------------------------;

;----[ EXTERNAL LABELS ]------------------------------------------------------------------------;

;{
	
	extern	write_rtc,read_rtc,rtc_convert,i2c_common_setup
	
;}
	

;----[ RTC MACROS ]-----------------------------------------------------------------------------;

;{
	
;DESCRIPTION:		Loads the data in datliteral into the address of addliteral in the RTC
;INPUT REGISTERS:	addliteral, datliteral
;OUTPUT REGISTERS:	None

rtc_set			macro		addliteral,datliteral

				banksel		0x73
				movfw		addliteral
				movwf		0x73
				banksel		0x74
				movfw		datliteral
				movwf		0x74
				pagesel		write_rtc	
				call		write_rtc
			
				endm

;DESCRIPTION:		Read RTC at addliteral and convert into both binary and two-digit ASCII
;INPUT REGISTERS:	addliteral
;OUTPUT REGISTERS:	0x75, 0x77, 0x78

rtc_read		macro		addliteral

				movfw		addliteral
				banksel		0x73
				movwf		0x73
				pagesel		read_rtc
				call		read_rtc
				banksel		0x75
				movf		0x75,w
				pagesel		rtc_convert
				call		rtc_convert 
			  
				endm
			
;}