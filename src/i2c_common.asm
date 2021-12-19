;----| SUMMARY |--------------------------------------------------------------------------------;
;													 						 					;
;	Author:			Duluxan Sritharan												 			;
;	Company:		Team 40														 				;
;	Date:			April 14, 2009																;
;																			 					;
;	Hardware: 		MicroChip PIC16F877												 			;
;	Assembler:		mpasm.exe														 			;
;																			 					;
;	Filename:		i2c_common.asm													 			;
;	File Version:	Release														 				;
;	Project Files:	STRG.asm												 		 			;
;					rtc_macros.inc													 			;
;																			 					;
;-----------------------------------------------------------------------------------------------;

;----[ CONFIGURATIONS ]-------------------------------------------------------------------------;

;{
	
	include <p16f877.inc>
	errorlevel	-302
	errorlevel	-305

;}


;----[ GLOBAL LABELS ]--------------------------------------------------------------------------;

;{

	global	write_rtc,read_rtc,rtc_convert,i2c_common_setup

;}


;----[ DEFINITION AND VARIABLE DECLARATIONS ]---------------------------------------------------;

;{

	cblock 0x71						;these variable names are for reference only. The following
		dt1					;0x71	 addresses are used for the RTC module
		dt2					;0x72
		ADD					;0x73
		DAT					;0x74
		DOUT				;0x75
		B1					;0x76
		dig10				;0x77
		dig1				;0x78
	endc
	
;}


;----[ I2C MACROS ]-----------------------------------------------------------------------------;

;{

;DESCRIPTION:		If bad ACK bit received, goto err_address
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None

i2c_common_check_ack		macro	err_address	
		
				banksel		SSPCON2
				btfsc		SSPCON2,ACKSTAT
				goto		err_address
		
				endm

;DESCRIPTION:		Initiate start condition on the bus
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None

i2c_common_start			macro
		
				banksel		SSPCON2
				bsf			SSPCON2,SEN
				btfsc		SSPCON2,SEN
				goto		$-1
			
				endm

;DESCRIPTION:		Initiate stop condition on the bus
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None

i2c_common_stop				macro
		
				banksel		SSPCON2
				bsf			SSPCON2,PEN
				btfsc		SSPCON2,PEN
				goto		$-1
			
				endm

;DESCRIPTION:		Initiate repeated start on the bus for changing direction of SDA without stop
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None

i2c_common_repeatedstart	macro
	
				banksel		SSPCON2
				bsf			SSPCON2,RSEN
				btfsc		SSPCON2,RSEN
				goto		$-1
			
				endm

;DESCRIPTION:		Send an acknowledge to slave device
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None

i2c_common_ack				macro

				banksel		SSPCON2
				bcf			SSPCON2,ACKDT
				bsf			SSPCON2,ACKEN
				btfsc		SSPCON2,ACKEN
				goto		$-1
			
				endm

;DESCRIPTION:		Send a not acknowledge to slave device
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None

i2c_common_nack				macro
	
				banksel		SSPCON2
				bsf			SSPCON2,ACKDT
				bsf			SSPCON2,ACKEN
				btfsc		SSPCON2,ACKEN
				goto		$-1
			
				endm

;DESCRIPTION:		Writes W to SSPBUF and send to slave device
;INPUT REGISTERS:	w
;OUTPUT REGISTERS:	SSPBUF

i2c_common_write			macro	
	
				banksel		SSPBUF
				movwf		SSPBUF
				banksel		SSPSTAT
				btfsc		SSPSTAT,R_W			; While transmit is in progress, wait
				goto		$-1
				banksel		SSPCON2
			
				endm

;DESCRIPTION:		Reads data from slave and saves it in W.
;INPUT REGISTERS:	SSPBUF
;OUTPUT REGISTERS:	w

i2c_common_read				macro
		
				banksel		SSPCON2
				bsf			SSPCON2,RCEN		; Begin receiving byte from
				btfsc		SSPCON2,RCEN
				goto		$-1
				banksel		SSPBUF
				movf		SSPBUF,w
			
				endm

;}


				code
	
;----[ I2C FUNCTIONS ]--------------------------------------------------------------------------;

;{
	
;DESCRIPTION:		Sets up I2C as master device with 100kHz baud rate
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None

i2c_common_setup
		
				banksel		SSPSTAT
				clrf 		SSPSTAT				; I2C line levels, and clear all flags
				movlw 		d'24'				; 100kHz baud rate: 10MHz osc / [4*(24+1)]
				banksel		SSPADD
				movwf		SSPADD				; RTC only supports 100kHz
			
				movlw		b'00001000'			; Config SSP for Master Mode I2C
				banksel		SSPCON
				movwf		SSPCON
				bsf			SSPCON,SSPEN		; Enable SSP module
			
				i2c_common_stop        			; Ensure the bus is free
			
				bcf			PCLATH,3
				bcf			PCLATH,4
			
				return

;}

;----[ RTC FUNCTIONS ]--------------------------------------------------------------------------;

;{

;DESCRIPTION:		Handles writing data to RTC
;INPUT REGISTERS:	0x73, 0x74
;OUTPUT REGISTERS:	None

write_rtc
				i2c_common_start				; Select the DS1307 on the bus, in WRITE mode
		
				movlw		0xD0				; DS1307 address | WRITE bit
		
				i2c_common_write
				i2c_common_check_ack   WR_ERR
			
				banksel		0x73				; Write data to I2C bus (Register Address in RTC)
				movf		0x73,w				; Set register pointer in RTC
		
				i2c_common_write
				i2c_common_check_ack   WR_ERR
			
				banksel		0x74				; Write RTC data to I2C bus 
				movf		0x74,w				; Write data to register in RTC
		
				i2c_common_write
				i2c_common_check_ack   WR_ERR
		
				goto		WR_END
		
				WR_ERR
		
				nop
		
				WR_END  

				i2c_common_stop					; Release the I2C bus
		
				bcf			PCLATH,3
				bcf			PCLATH,4
		
				return

;DESCRIPTION:		This reads from the RTC and saves it into DOUT or address 0x75
;INPUT REGISTERS:	0x73
;OUTPUT REGISTERS:	0x75

read_rtc	
				i2c_common_start				; Select the DS1307 on the bus, in WRITE mode
		
				movlw		0xD0				; DS1307 address | WRITE bit
		
				i2c_common_write
				i2c_common_check_ack   RD_ERR
			
				banksel		0x73				; Write data to I2C bus (Register Address in RTC)
				movf		0x73,w				; Set register pointer in RTC
		
				i2c_common_write
				i2c_common_check_ack   RD_ERR
			
				i2c_common_repeatedstart		; Re-Select the DS1307 on the bus, in READ mode
			
				movlw		0xD1				; DS1307 address | READ bit
		
				i2c_common_write
				i2c_common_check_ack   RD_ERR
				i2c_common_read					; Read data from I2C bus (Contents of Register in RTC)
			
				banksel		0x75
				movwf		0x75
		
				i2c_common_nack					; Send acknowledgement of data reception
			
				goto		RD_END
			
				RD_ERR 
			
				nop
				
				RD_END	i2c_common_stop			; Release the I2C bus
		
				bcf			PCLATH,3
				bcf			PCLATH,4
			
				return

;DESCRIPTION:		Converts a binary number into two digit ASCII numbers
;INPUT REGISTERS:	w
;OUTPUT REGISTERS:	0x77, 0x78

rtc_convert   
				banksel		0x76
				movwf		0x76				; B1 = HHHH LLLL
				swapf		0x76,w				; W  = LLLL HHHH
				andlw		0x0f				; Mask upper four bits 0000 HHHH
				addlw		0x30				; convert to ASCII
				movwf		0x77				; saves into 10ths digit
			
				banksel		0x76
				movf		0x76,w
				andlw		0x0f				; w  = 0000 LLLL
				addlw		0x30				; convert to ASCII		
				movwf		0x78				; saves into 1s digit
			
				bcf			PCLATH,3
				bcf			PCLATH,4
			
				return
			
;}


				end