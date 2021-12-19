;----| SUMMARY |--------------------------------------------------------------------------------;
;													 						 					;
;	Author:			Duluxan Sritharan												 			;
;	Company:		Team 40														 				;
;	Date:			April 14, 2009													 			;
;																			 					;
;	Hardware: 		MicroChip PIC16F877												 			;
;	Assembler:		mpasm.exe														 			;
;																			 					;
;	Filename:		STRG.asm														 			;
;	File Version:	Release														 				;
;	Project Files:	i2c_common.asm												 	 			;
;					rtc_macros.inc													 			;
;																			 					;
;-----------------------------------------------------------------------------------------------;

;----[ CONFIGURATIONS ]-------------------------------------------------------------------------;

;{
	__CONFIG 	_CP_OFF & _WDT_OFF & _BODEN_OFF & _PWRTE_ON & _HS_OSC & _WRT_ENABLE_ON & _CPD_OFF & _LVP_OFF & _DEBUG_OFF
									; set configuration register
	errorlevel 	-302				; ignore bank switch warning
	list p=16f877, r = DEC			; list directive to define processor
	
	#include <p16f877.inc>        	; processor specific variable definitions
	#include <rtc_macros.inc>		; macros for real-time clock
;}

  
;----[ CONSTANTS ]------------------------------------------------------------------------------;

;{

; mnemonics for LCD bits (PORTD)

RS				equ			2
E				equ			3

; mnemonics for RTC addresses

RTC_Second		equ			0
RTC_Minute		equ			1
RTC_Hour		equ			2
RTC_Date		equ			4
RTC_Month		equ			5
RTC_Year		equ			6

; mnemonics for EEPROM addresses

xAdmID			equ			0
xAdmPW			equ			2
xAdmAccess		equ			4
xModConfig		equ			5
xMod1ID			equ			6
xMod2ID			equ			8
xMod3ID			equ			10
xMod4ID			equ			12
xMod5ID			equ			14
xUActive		equ			16
xGActive		equ			17

xUser1ID		equ			18
xUser1PW		equ			20
xUser1Access	equ			22
xUser1Valid		equ			23
xGuest1PW		equ			29
xGuest1Access	equ			31
xGuest1Valid	equ			32

xUser4ID		equ			78
xUser4PW		equ			80
xUser4Access	equ			82
xUser4Valid		equ			83
xGuest4PW		equ			89
xGuest4Access	equ			91
xGuest4Valid	equ			92

xUser1Log		equ			98
xUser4Log		equ			206

xRestart		equ			255

;}

;----[ REGISTERS ]------------------------------------------------------------------------------;

;{
	
clock			equ			0x75		; address of stored binary clock value
dig10			equ			0x77		; address of parsed ten's digit
dig1			equ			0x78		; address of parsed one's digit
rtcAdr			equ			0x79		; address of register for field
rtcVal			equ			0x7A		; address of register for value

;}


;----[ VARIABLES ]------------------------------------------------------------------------------;

;{
	
	cblock H'20'
	
		; variables for taking input from keypad
		
		num_check
		num_test
		key_no
	
		; variables for RTC read/write
				
		field
		clockvalue
		RTC_value
		RTC_addr
		
		; variables used to store date/time information
	
		hour
		minute
		second
		date
		month
		year

		ehour
		eminute
		esecond
		edate
		emonth
		eyear
		
		; variables used to store elapsed time in log generation
		
		hundred
		ten
		one
		duration
		
		; variables used in delay functions

		delay1
		delay2
		delay3
		
		; variables for EEPROM read/write
		
		value
		addr
	
		; variables for recording login input
	
		IDchar1
		IDchar2
		PWchar1
		PWchar2

		; variables for login verification

		check
		check_bit
		wrong
		
		; variables for printing messages
		
		table_index
		str_size
		
		; variables for inheritance of functions in user interface

		IDAddr
		PWAddr
		AccAddr
		LogAddr
		
		modaddr
		modconfig
		uconfig
		gconfig
		curlog
		access
		parent_access
		child_access
		child_addr
		mod_bit
	
		; variables for selecting screens and menus in interface hierarchy
	
		screen_sel
		module_sel
		user_sel
		guest_sel
		orig_order
		order
			
		; variables for general purpose computation
		
		count
		comp
				
		; temporary variables
		
		temp
		tempaddr
		lcd_tmp
		kp_ret
		kp_tmp
		kp_tmp1
		kp_tmp2
		kp_tmp3
		kp_tmp4
		char1
		char2
		long
		
	endc

;}


;----[ MACROS ]---------------------------------------------------------------------------------;

;{
	
;	Writes string at 'str' label to LCD
	
WRT_STR			macro		str		
				local		loop, prep
		
				movwf		str_size			; Counter for character offset
		
loop			movfw		str_size
				pagesel		str
				call		str					; Goto 'str' label + str_size offset
				pagesel		Main
				movwf		temp				; Temp holds the character
				incf		temp, f				; Check if it's 0 (end of string)
				decfsz		temp, f
				goto		prep				; If not....goto to prep
				return							; Else...return

prep			incf		str_size, f			; Increase offset
				call		WrtLCD				; Print character
				goto 		loop				; Repeat

				endm

; 	Ensures that PCL is on same page as 'table' label

PCLSwitch		macro		table	
				movwf		table_index			; Save current index
				movlw		HIGH table			; Get the page table is on
				movwf		PCLATH				; Move PCLATH to that page
				movfw		table_index			; Move index back into the working reg
				addlw		LOW	table			; Offset label
				btfsc		STATUS,C			; Check carry bit
				incf		PCLATH,f			; If in next page, increment PCLATH
				movwf		PCL					; Write the correct address to PCL
				endm

;}

Page0

;----[ VECTORS ]--------------------------------------------------------------------------------;

;{
	
				org       	0x0000     			; Standard reset
				goto      	Main       			; Goto main code.

				org			0x0004				; Interrupt reset
				goto		Main				; No interrupts

;}


;----[ INITIALIZATION ]-------------------------------------------------------------------------;

;{

;DESCRIPTION:		Initializes peripherals, ports and system
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None
       
Main			call		LongDelay
				pagesel		i2c_common_setup
				call		i2c_common_setup	; set-up I2C bus
				pagesel		InitPort
				call		InitPort			; set-up ports
				pagesel		Main
		
				call		InitLCD				; set-up LCD
	
;DESCRIPTION:		Initializes storage system
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None
			
InitSystem		movlw		xRestart
				movwf		addr
				call		ReadROM
				movwf		value
				incfsz		value, f			; value = 255 -> system reset

				goto		IDMenu
		
				call		InitClock
				call		InitAdmin
				call		InitROM
			
				goto		AdmMenu

;DESCRIPTION:		Initializes the clock by clearing all fields
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None
		
InitClock		movlw		0
				movwf		value
			
				movlw		RTC_Second
				movwf		field
			
				call		WriteRTC
				incf		field, f
				call		WriteRTC
				incf		field, f
				call		WriteRTC
			
				movlw		RTC_Date
				movwf		field
			
				call		WriteRTC
				incf		field, f
				call		WriteRTC
				incf		field, f
				call		WriteRTC
			
				return

;DESCRIPTION:		Initializes administrator account
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None
			
InitAdmin		call		CursorOn
			
				call		ClrLCD				; Set administrator ID
				call		AdminID
				call		Line2LCD

				movlw		xAdmID			
				movwf		IDAddr
				movwf		addr

				call		GetFour
				call		StoreFour
				
				call		ClrLCD				; Set administrator PW
				call		AdminPW
				call		Line2LCD
	
				movlw		xAdmPW
				movwf		PWAddr
				movwf		addr

				call		GetFour
				call		StoreFour
			
				movlw		xAdmAccess			; Retrieve administrator access (all)
				movwf		addr
				call		ReadROM
				movwf		access
			
				return

;DESCRIPTION:		Initializes EEPROM on PIC
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None
			
InitROM			movlw		0
				movwf		value

				movlw		xModConfig			; no modules configured
				movwf		addr
				call		WrtROM
			
				movlw		xUActive			; no users active
				movwf		addr
				call		WrtROM
	
				movlw		xGActive			; no guests active
				movwf		addr
				call		WrtROM

				movlw		xRestart			; system initialized
				movwf		addr
				call		WrtROM
			
			
				movlw		4
				movwf		count

				movlw		xUser1ID
				movwf		addr
			
				call		ResetAccount		; reset account data
				movlw		20
				addwf		addr, f
				decfsz		count, f
				goto		$-4
			
				movlw		4
				movwf		count
			
				movlw		xUser1Log			; reset log data
				movwf		addr
			
				call		ResetLog
				movlw		36
				addwf		addr, f
				decfsz		count, f
				goto		$-4
			
				return
		
;DESCRIPTION:		Resets/initializes account data in EEPROM
;INPUT REGISTERS:	addr
;OUTPUT REGISTERS:	None
					
ResetAccount
					
				movlw		0
				movwf		value
			
				movlw		4					; user has access to no modules
				addwf		addr, f
				call		WrtROM
			
				movlw		9					; guest has access to no modules
				addwf		addr, f
				call		WrtROM
	
				movlw		13				
				subwf		addr, f
			
				return

;DESCRIPTION:		Resets/initializes log data in EEPROM
;INPUT REGISTERS:	addr
;OUTPUT REGISTERS:	None

ResetLog		movfw		addr				; reset pointer to next log
				movwf		value
				call		WrtROM
		
				movlw		0xFF				; mark all log slots as empty (d'255)
				movwf		value
		
				incf		addr, f
				movlw		5
				movwf		temp
				movlw		7
			
				call		WrtROM
				movlw		7
				addwf		addr, f
				decfsz		temp, f
				goto		$-4
			
				movlw		36
				subwf		addr, f
			
				return
		
;}


;----[ LOGIN ]----------------------------------------------------------------------------------;

;{

;DESCRIPTION:		Displays date/time and waits for input
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None
	
Standby			bcf			PORTC, 7			; make sure no solenoids are powered
				bcf			PORTC, 6
				call		ClrLCD
				call		CursorOff
				call		Line1LCD
				call		PrintDate			; display date
				call		PrintSpace
				call		PrintSpace
				call		Press
				call		Line2LCD
				call		PrintTime			; display time
				call		PrintSpace
				call		AnyKey
	
StandbyLoop		call		Line2LCD
				call		PrintTime			; update time
		
				btfss		PORTB, 1			
				goto		StandbyLoop			; loop if no input
				btfsc		PORTB, 1	
				goto		$-1
				goto		InitSystem			; else set-up system

;DESCRIPTION:		Checks if current users have expired and shows log-in menu
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	IDchar1, IDchar2, PWchar1, PWchar2

IDMenu			call		ValidVerify			; checks user expiry	
			
				call		ClrLCD
									
				call		CursorOn			; prompts for ID
				call		UserID					
				call		Line2LCD
				
				call		GetFour
				movfw		char1
				movwf		IDchar1
				movfw		char2
				movwf		IDchar2
			
				call		ClrLCD				; prompts for password
				call		Password				
				call		Line2LCD

				call		GetFour
				movfw		char1
				movwf		PWchar1
				movfw		char2
				movwf		PWchar2
	
;DESCRIPTION:		Checks if operator is administrator
;INPUT REGISTERS:	IDchar1, IDchar2, PWchar1, PWchar2
;OUTPUT REGISTERS:	None
	
AdminVerify		movlw		xAdmID				; load admin location to check
				movwf		IDAddr
				movlw		xAdmPW
				movwf		PWAddr
				movlw		xAdmAccess
				movwf		AccAddr
				movlw		0
				movwf		LogAddr
	
				call		IDCompare			; compares characters

				btfss		wrong, 2			; if not an admin, check if a user
				goto		UserVerify
			
				goto		AdmMenu				; else proceed to admin menu

;DESCRIPTION:		Checks if operator is a typical user
;INPUT REGISTERS:	IDchar1, IDchar2, PWchar1, PWchar2
;OUTPUT REGISTERS:	None

UserVerify		movlw		xUser1ID			; load user location to check
				movwf		IDAddr
				movlw		xUser1PW
				movwf		PWAddr
				movlw		xUser1Access
				movwf		AccAddr
				movlw		xUser1Log
				movwf		LogAddr
	
				movlw		16					; xth user has xth bit = 1
				movwf		check_bit

UVerifyLoop		movfw		uconfig				; check if user exists
				andwf		check_bit, w
				movwf		check

				call		IDCompare			; compares characters

				btfss		wrong, 2			
				goto		UNext
				incf		check,f
				decfsz		check, f
				goto		UserMenu			
		
UNext			movlw		20					; next user (i+20) in EEPROM
				addwf		IDAddr, f
				addwf		PWAddr, f
				addwf		AccAddr, f
				movlw		36					; next log (i+36) in EEPROM
				addwf		LogAddr, f

				rrf			check_bit, f

				btfss		check_bit, 0
				goto		UVerifyLoop

;DESCRIPTION:		Checks if operator is a guest
;INPUT REGISTERS:	IDchar1, IDchar2, PWchar1, PWchar2
;OUTPUT REGISTERS:	None

GuestVerify		movlw		xUser1ID			; load guest location to check
				movwf		IDAddr
				movlw		xGuest1PW
				movwf		PWAddr
				movlw		xGuest1Access
				movwf		AccAddr
				movlw		xUser1Log
				movwf		LogAddr

				movlw		16					; xth guest has xth bit = 1
				movwf		check_bit			

GVerifyLoop		movfw		gconfig				; check if guest exists
				andwf		check_bit, w
				movwf		check

				call		IDCompare			; compares characters

				btfss		wrong, 2
				goto		GNext
				incf		check,f
				decfsz		check, f
				goto		GuestMenu			; guest exists and log-in correct
			
GNext			movlw		20					; next guest (i+20) in EEPROM
				addwf		IDAddr, f
				addwf		PWAddr, f
				addwf		AccAddr, f
				movlw		36					; next log (i+36) in EEPROM
				addwf		LogAddr, f

				rrf			check_bit, f

				btfss		check_bit, 0
				goto		GVerifyLoop

				call		ClrLCD				; login info is wrong
				call		CursorOff
				call		Denied
			
				call		HumanDelay
		
				goto		IDMenu				; try again

;DESCRIPTION:		Checks if any user or guest accounts have expired
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	uconfig, gconfig

ValidVerify		call		GetTime				; get the current time

				movlw		xUActive			; get configuration for active users
				movwf		addr
				call		ReadROM	
				movwf		uconfig
		
				movlw		16					; check if user x is active
				movwf		check_bit
				movfw		uconfig
				movwf		check

				movlw		xUser1Valid
				movwf		addr

				call		CompareTime			; cycle through users
			
				movlw		xUActive			; update active users
				movwf		addr
				movfw		check
				movwf		value
				movwf		uconfig			
				call		WrtROM


				movlw		xGActive			; get configuration for active guests
				movwf		addr
				call		ReadROM
				movwf		gconfig

				movlw		16					; check if guest x is active
				movwf		check_bit
				movfw		gconfig
				movwf		check

				movlw		xGuest1Valid
				movwf		addr

				call		CompareTime			; cycle through guests
		
				movfw		uconfig
				andwf		check, w
				movwf		gconfig				; ensure guests don't outlast users
				movwf		value

				movlw		xGActive			; update active guests
				movwf		addr
				call		WrtROM

				return

;DESCRIPTION:		Checks if any User/Guest X has expired
;INPUT REGISTERS:	check, check_bit, addr
;OUTPUT REGISTERS:	check

CompareTime
				movfw		check_bit			; check if current user exists
				andwf		check, w
				btfss		STATUS, Z
				goto		$+4
				movlw		5
				addwf		addr, f
				goto		CheckNext
			
				call		ClrLCD
				
				call		ReadROM				; get expiry date/time
				movwf		emonth
	
				incf		addr, f
				call		ReadROM
				movwf		edate
	
				incf		addr, f
				call		ReadROM
				movwf		eyear
	
				incf		addr, f
				call		ReadROM
				movwf		ehour
		
				incf		addr, f
				call		ReadROM
				movwf		eminute
	
				incf		addr, f
				call		ReadROM
				movwf		esecond
			
				movfw		year				
				subwf		eyear, w
				btfss		STATUS, C
				goto		AccExpired			; check if year expired
				btfss		STATUS, Z
				goto		CheckNext
			
				movfw		month
				subwf		emonth, w
				btfss		STATUS, C
				goto		AccExpired			; check if month expired
				btfss		STATUS, Z
				goto		CheckNext
			
				movfw		date
				subwf		edate, w
				btfss		STATUS, C
				goto		AccExpired			; check if day expired
				btfss		STATUS, Z
				goto		CheckNext
			
				movfw		hour
				subwf		ehour, w
				btfss		STATUS, C
				goto		AccExpired			; check if hour expired
				btfss		STATUS, Z
				goto		CheckNext
			
				movfw		minute
				subwf		eminute, w
				btfss		STATUS, C
				goto		AccExpired			; check if minute expired
				btfss		STATUS, Z
				goto		CheckNext
			
				movfw		second
				subwf		esecond, w			; check if second expired
				btfsc		STATUS, C
				goto		CheckNext

AccExpired		comf		check_bit, w		; remove active status
				andwf		check, f

CheckNext		movlw		15					; goto next user/guest
				addwf		addr, f
				rrf			check_bit, f

				btfss		check_bit, 0
				goto		CompareTime

				return

;DESCRIPTION:		Checks if login info matches user/guest X
;INPUT REGISTERS:	IDAddr, PWAddr, LogAddr, AccAddr
;OUTPUT REGISTERS:	wrong, access, curlog

IDCompare		movlw		0					; wrong = # right characters
				movwf		wrong

				movfw		IDAddr				; check if ID characters are same
				movwf		addr
				movfw		IDchar1
				movwf		value
				call		CheckROM
				addwf		wrong, f

				incf		addr, f
				movfw		IDchar2
				movwf		value
				call		CheckROM
				addwf		wrong, f

				movfw		PWAddr				; check if PW characters are same
				movwf 		addr
				movfw		PWchar1
				movwf		value
				call		CheckROM
				addwf		wrong, f
		
				incf		addr, f
				movfw		PWchar2
				movwf		value
				call		CheckROM
				addwf		wrong, f
		
				movfw		AccAddr				; retrieve access configuration
				movwf		addr
				call		ReadROM
				movwf		access

				movfw		LogAddr				; retrieve pointer to next log
				movwf		addr
				call		ReadROM
				movwf		curlog

				return

;DESCRIPTION:		Prints welcome information for correct login
;INPUT REGISTERS:	IDAddr
;OUTPUT REGISTERS:	None

Greeting		call		ClrLCD
				call		CursorOff
			
				call		Welcome				; print "Welcome"
				call		PrintSpace
			
				movfw		IDAddr				; print user name
				movwf		addr
				call		PrintName
			
				movlw		"!"
				call		WrtLCD
						
				call		HumanDelay
			
				call		CursorOn
			
				return
			
;}


;----[ ADMINISTRATOR MENU ]---------------------------------------------------------------------;

;{

;DESCRIPTION:		Generates administrator main menu
;INPUT REGISTERS:	IDAddr, PWaddr, Accaddr, access
;OUTPUT REGISTERS:	None
	
AdmMenu			call		Greeting			; display greeting
			
				movlw		64
				movwf		screen_sel			; register for choosing screen

AdmLoop			call		ClrLCD

				btfsc		screen_sel, 6		; display options
				call		Configure
				btfsc		screen_sel, 5
				call		ManageAcc
				btfsc		screen_sel, 4
				call		OpenMod
				btfsc		screen_sel, 3
				call		AdjDT
				btfsc		screen_sel, 2
				call		ChangePW
				btfsc		screen_sel, 1
				call		ResetSystem
				btfsc		screen_sel, 0
				call		Logoff
		
				call		Line2LCD
				call		YesOpt

Adm_Input		call		KPScroll			; poll for input
				movwf		key_no
				btfsc		key_no, 0
				goto		ARightCirc			; next option
				btfsc		key_no, 1
				goto		ADo_Opt				; do current option
				goto		ALeftCirc			; previous option

ADo_Opt			btfsc		screen_sel, 6		; branch to sub-menu
				goto		Do_Configure		; configure modules
				btfsc		screen_sel, 5
				goto		Do_Manage			; manage accounts
				btfsc		screen_sel, 4
				call		Do_Open;			; open modules
				btfsc		screen_sel, 4
				goto		AdmLoop
				btfsc		screen_sel, 3
				goto		Do_AdjDT			; adjust date and time
				btfsc		screen_sel, 2
				call		Do_ChangePW			; change admin password
				btfsc		screen_sel, 2
				goto		AdmLoop
				btfsc		screen_sel, 1
				goto		Do_ResetSystem		; reset system
				btfsc		screen_sel, 0	
				goto		Standby				; logoff
	
ARightCirc		bcf			STATUS, C			; next screen
				rrf			screen_sel, f
				btfss		STATUS, C
				goto		AdmLoop
				movlw		B'01000000'
				movwf		screen_sel
				goto		AdmLoop
				
ALeftCirc		bcf			STATUS, C			; previous screen
				rlf			screen_sel, f
				btfss		screen_sel, 7
				goto		AdmLoop
				movlw		B'00000001'
				movwf		screen_sel
				goto		AdmLoop
			
;}


;----[ USER MENU ]------------------------------------------------------------------------------;

;{

;DESCRIPTION:		Generates user main menu
;INPUT REGISTERS:	IDAddr, PWaddr, Accaddr, LogAddr, access, curlog
;OUTPUT REGISTERS:	None
	
UserMenu		call		Greeting			; display greeting
			
				movlw		8					; register for choosing screen
				movwf		screen_sel

				movlw		xGActive
				movwf		addr
				call		ReadROM
				movwf		gconfig

UserLoop		call		ClrLCD
	
				btfsc		screen_sel, 3		; display options
				call		OpenMod
				btfsc		screen_sel, 2
				call		ChangePW
				btfsc		screen_sel, 1
				call		GuestAcc
				btfsc		screen_sel, 0
				call		Logoff
	
				call		Line2LCD
			
				btfsc		screen_sel, 1		; display action item if guest screen
				goto		$+3
				call		YesOpt
				call		User_Input
				movfw		gconfig
				andwf		check_bit, w
				movwf		check
				btfsc		STATUS, Z
				goto		$+3
				call		DelOpt
				goto		User_Input
				call		AddOpt

User_Input		call		KPScroll			; poll for input
				movwf		key_no
				btfsc		key_no, 0
				goto		URightCirc			; next option
				btfsc		key_no, 1
				goto		UDo_Opt				; do option
				goto		ULeftCirc			; previous option
		

UDo_Opt			btfsc		screen_sel, 3		; branch to sub_menu
				call		Do_Open;			; open module
				btfsc		screen_sel, 3
				goto		UserLoop
				btfsc		screen_sel, 2
				call		Do_ChangePW			; change password
				btfsc		screen_sel, 2
				goto		UserLoop	
				btfsc		screen_sel, 1
				goto		Do_ManageGuest		; create guest account
				btfsc		screen_sel, 1
				goto		UserLoop		
				goto		UserSave			; logoff
	
URightCirc		bcf			STATUS, C			; next screen
				rrf			screen_sel, f
				btfss		STATUS, C
				goto		UserLoop
				movlw		B'00001000'
				movwf		screen_sel
				goto		UserLoop
				
ULeftCirc		bcf			STATUS, C			; previous screen
				rlf			screen_sel, f
				btfss		screen_sel, 4
				goto		UserLoop
				movlw		B'00000001'
				movwf		screen_sel
				goto		UserLoop	


Do_ManageGuest	incf		check, f			; add/delete guest option
				decfsz		check, f
				goto		GuestDel
			

GuestAdd		movfw		PWAddr				; delete outdated guest access
				addlw		11
				movwf		addr
				movlw		0
				movwf		value
				call		WrtROM
				movlw		2
				subwf		addr, f

				call		AddGuest			; create guest account
				movfw		check_bit
				iorwf		gconfig, f
				goto		UserLoop
			
GuestDel		comf		check_bit, w		; delete guest active status
				andwf		gconfig, f
				goto		UserLoop

UserSave		movfw		gconfig				; save any changes to guest
				movwf		value	
				movlw		xGActive
				movwf		addr
				call		WrtROM
				goto		Standby				; logoff
;}


;----[ GUEST MENU ]-----------------------------------------------------------------------------;

;{
	
;DESCRIPTION:		Generates guest main menu
;INPUT REGISTERS:	IDAddr, PWaddr, Accaddr, LogAddr, access, curlog
;OUTPUT REGISTERS:	None	

GuestMenu		call		Greeting			; display greeting
			
				movlw		1
				movwf		screen_sel			; register for choosing screen

GuestLoop		call		ClrLCD

				btfss		screen_sel, 0		; display options
				call		Logoff			
				btfsc		screen_sel, 0
				call		OpenMod
	
				call		Line2LCD
				call		YesOpt

Guest_Input		call		KPScroll			; poll for input
				movwf		key_no
				btfsc		key_no, 1	
				goto		GDo_Opt				; do option
				goto		GCirc				; next/prev screen
		

GDo_Opt			btfsc		screen_sel, 0		; branch to sub-menus
				call		Do_Open;			; open modules
				btfsc		screen_sel, 0
				goto		GuestLoop
				goto		Standby				; log off

GCirc			movlw		B'00000001'			; display next/prev screen
				xorwf		screen_sel, f
				goto		GuestLoop 

;}


;----[ CONFIGURE SYSTEM ]-----------------------------------------------------------------------;

;{
	
;DESCRIPTION:		Generates menu for configuring which modules are active
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None
	
Do_Configure	movlw		xModConfig
				movwf		addr
				call		ReadROM
				movwf		modconfig			; get current system configuration

				movlw		2
				movwf		module_sel			; mod X -> xth bit = 1 of module_sel
				movlw		xMod1ID
				movwf		addr
				movlw		1
				movwf		order
		
		
ConfigureLoop	btfss		module_sel, 0		; module or back screen
				goto		ConfigureMod
				call		ClrLCD
				call		Back
				call		Line2LCD
				call		YesOpt
				goto		Config_Input

ConfigureMod	call		ClrLCD				; print module number
				call		Module
				call		PrintSpace
				call		Enumerate
				call		PrintSpace
		
				movfw		modconfig
				andwf		module_sel, w
				movwf		check
				incf		check, f
				decfsz		check, f
				goto		OldMod				; check if slot is occupied

				call		Free				; new module
				call		Line2LCD
				call		AddOpt				; display Add Option
				goto		Config_Input
		
OldMod			call		PrintName			; module already configured
				call		Line2LCD
				call		RemoveOpt			; display remove option
				goto		Config_Input


Config_Input	call		KPScroll			; poll for input
				movwf		key_no
				btfsc		key_no, 0
				goto		CRightCirc			; next module screen
				btfsc		key_no, 1
				goto		CDo_Opt				; branch to sub-menu
				goto		CLeftCirc			; previous module screen
			
CDo_Opt			btfsc		module_sel, 0
				goto		ConfigSave			; back screen - save changes
				incf		check, f
				decfsz		check, f
				goto		ConfigDel			; slot taken - delete module
				goto		ConfigAdd			; slot free - add module

ConfigAdd		call		AddModule			; prompt for module name
				movfw		module_sel
				iorwf		modconfig, f		; update active modules
				goto		ConfigureLoop

ConfigDel		comf		module_sel, w		; remove active status
				andwf		modconfig, f
				goto		ConfigureLoop

ConfigSave		movfw		modconfig			; save settings
				movwf		value	
				movlw		xModConfig
				movwf		addr
				call		WrtROM
				goto		AdmLoop

CRightCirc		incf		order, f			; change screen to next module
				movlw		2
				addwf		addr, f

				bcf			STATUS, C
				rlf			module_sel, f
				btfss		module_sel, 6
				goto		ConfigureLoop
				movlw		B'00000001'
				movwf		module_sel

				movlw		0
				movwf		order
				movlw		xMod1ID
				movwf		addr
				movlw		2
				subwf		addr, f
				goto		ConfigureLoop
				
CLeftCirc		decf		order, f			; change screen to previous module
				movlw		2
				subwf		addr, f

				bcf			STATUS, C
				rrf			module_sel, f
				btfss		STATUS, C
				goto		ConfigureLoop
				movlw		B'00100000'
				movwf		module_sel

				movlw		5
				movwf		order
				movlw		xMod5ID
				movwf		addr
				goto		ConfigureLoop	

;DESCRIPTION:		Prompts and saves name of Module X
;INPUT REGISTERS:	addr
;OUTPUT REGISTERS:	None

AddModule		call		ClrLCD				; prompt for module name
				call		ModID
				call		Line2LCD

				call		GetFour
				call		StoreFour
		
				decf		addr, f

				return
;}


;----[ CONFIGURE USERS/GUEST ]------------------------------------------------------------------;

;{

;DESCRIPTION:		Generates menus for managing/creating/deleting users
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None

Do_Manage		movlw		xUActive			; get current status of users
				movwf		addr
				call		ReadROM
				movwf		uconfig

				movlw		16					; User X = 5-Xth bit of uconfig
				movwf		user_sel
				movlw		1
				movwf		order
				movlw		xUser1ID
				movwf		addr
				movlw		xUser1Log
				movwf		LogAddr		
		
ManageLoop		btfss		user_sel, 0			; check if back screen
				goto		ManageUser
				call		ClrLCD
				call		Back
				call		Line2LCD
				call		YesOpt
				goto		Manage_Input

ManageUser		call		ClrLCD				; screen for managing user X

				call		User				; print user number
				call		PrintSpace
		
				call		Enumerate
				call		PrintSpace
		
				movfw		uconfig				; check if slot is free
				andwf		user_sel, w
				movwf		check
				incf		check, f
				decfsz		check, f
				goto		OldUser

				call		Free				; slot is free - allow adding
				call		Line2LCD
				call		AddOpt
				goto		Manage_Input
		
OldUser			call		PrintName			; slot is full - allowing managing
				call		Line2LCD
				call		ManageOpt
				goto		Manage_Input


Manage_Input	call		KPScroll			; poll for input
				movwf		key_no
				btfsc		key_no, 0
				goto		MRightCirc			; next screen
				btfsc		key_no, 1
				goto		MDo_Opt				; branch to sub-menu
				goto		MLeftCirc			; previous screen
		
MDo_Opt			btfsc		user_sel, 0			; save changes if back screen
				goto		ManageSave
				incf		check, f
				decfsz		check, f
				goto		UserManage			; manage users if slot is full
			
UserAdd			call		UserDelete			; delete current settings

				call		AddUser				; propagate new settings
				movfw		user_sel			; update changes to active setting
				iorwf		uconfig, f
				goto		ManageLoop
			
UserManage		movfw		order				; save current state in previous menu
				movwf		orig_order
			
				movlw		1					; display options
				movwf		order

				call		ClrLCD
			
				call		Enumerate
				call		Edit				; 1. Edit
				call		PrintSpace
				call		PrintSpace
				call		PrintSpace
				call		PrintSpace
			
				incf		order, f
				call		Enumerate			; 2. Logs
				call		Log
					
				call		Line2LCD
			
				incf		order, f
				call		Enumerate
				call		Delete				; 3. Delete
				call		PrintSpace
				call		PrintSpace
			
				incf		order, f
				call		Enumerate			; 4. Back
				call		Back
			
				movfw		orig_order			; restore parent menu settings
				movwf		order		
			
Action_Input	call		KPGetChar			; get number input
				call		KPHexToChar
				movwf 		key_no
				movlw		48
				subwf		key_no, f
			
				decfsz		key_no, f			
				goto		$+3
				call		AddUser				; change settings
				goto		UserManage
				decfsz		key_no, f
				goto		$+2
				goto		Do_AccessLog		; view logs
				decfsz		key_no, f
				goto		$+3
				call		UserDelete			; delete users
				goto		ManageLoop
				decfsz		key_no, f
				goto		Action_Input		; invalid input
				goto		ManageLoop			; go back

UserDelete		comf		user_sel, w			; delete active status
				andwf		uconfig, f
			
				movfw		addr
				movwf		tempaddr
			
				call		ResetAccount		; delete module assignments
			
				movfw		LogAddr
				movwf		addr
		
				call		ResetLog			; delete saved logs
			
				movfw		tempaddr
				movwf		addr
			
				return

ManageSave		movfw		uconfig				; save changes to user active status
				movwf		value	
				movlw		xUActive
				movwf		addr
				call		WrtROM
				goto		AdmLoop

MRightCirc		incf		order, f			; next user
				movlw		20
				addwf		addr, f
				movlw		36
				addwf		LogAddr, f
				bcf			STATUS, C
				rrf			user_sel, f
				btfss		STATUS, C
				goto		ManageLoop
				movlw		B'00010000'
				movwf		user_sel
				movlw		1
				movwf		order
				movlw		xUser1ID
				movwf		addr
				movlw		xUser1Log
				movwf		LogAddr
				goto		ManageLoop
				
MLeftCirc		decf		order, f			; previous user
				movlw		20
				subwf		addr, f
				movlw		36
				subwf		LogAddr, f
				bcf			STATUS, C
				rlf			user_sel, f
				btfss		user_sel, 5
				goto		ManageLoop
				movlw		B'00000001'
				movwf		user_sel
				movlw		5
				movwf		order
				movlw		xUser4ID
				addlw		20
				movwf		addr
				movlw		xUser4Log
				addlw		36
				movwf		LogAddr
				goto		ManageLoop	

				return

;DESCRIPTION:		Prompts for user name and inherits function from AddGuest
;INPUT REGISTERS:	addr, access
;OUTPUT REGISTERS:	None

AddUser			movfw		order			
				movwf		orig_order

				call		ClrLCD
				call		UserID
				call		Line2LCD
			
				movfw		check
				btfsc		STATUS, Z
				goto		$+3
				call		PrintName
				call		Line2LCD

				call		GetFour
				call		StoreFour
				
				incf		addr, f

				call		AddGuest			; remaining changes are same as guest

				movlw		4
				subwf		child_addr,w
				movwf		addr

				movfw		orig_order
				movwf		order	

				return	

;DESCRIPTION:		Prompts for password, module assignment and expiry
;INPUT REGISTERS:	addr, access
;OUTPUT REGISTERS:	None

AddGuest		call		ClrLCD				; prompt for password
				call		Password
				call		Line2LCD
	
				incf		check, f			; check if old or new user
				decfsz		check, w
				call		PrintName
				decfsz		check, f
				call		Line2LCD
	
				call		GetFour
				call		StoreFour
			
				movfw		addr
				addlw		2
				movwf		child_addr
			
				call		ClrLCD				; set expiry time	
				call		CursorOff
				call		ExpiryPrompt
				call		HumanDelay
				call		CursorOn			
			
				call		Expiry			

				decf		child_addr, f

				movfw		child_addr
				movwf		addr
				call		ReadROM
				movwf		child_access
		
				movfw		access
				movwf		parent_access
	
				call		ClrLCD				; assign modules
				call		CursorOff
				call		AssignModules
				call		HumanDelay
				call		CursorOn
		
				call		AssignModule
				
				movfw		PWAddr
				movwf		addr
	
				movfw		parent_access
				movwf		access

				return

;DESCRIPTION:		Updates/creates expiry times for users/guests
;INPUT REGISTERS:	child_addr
;OUTPUT REGISTERS:	None

Expiry			movfw		child_addr
				movwf		addr
						
				call		ClrLCD
				incf		check, f
				decfsz		check, w			; has expiry time been set already
				goto		ShowExpiry			; if so show stats
			
				call		ClrLCD
				call		DatePrompt
				
				call		Line2LCD
				call		TimePrompt

				goto		SetExpiry			; else prompt for new stats

ShowExpiry		call		ReadROM				; display current month expiry
				call		PrintBCD
				incf		addr, f

				movlw		"/"
				call		WrtLCD

				call		ReadROM				; display current date expiry
				call		PrintBCD
				incf		addr, f

				movlw		"/"
				call		WrtLCD

				call		ReadROM				; display current year expiry
				call		PrintBCD
				incf		addr, f

				call		Line2LCD
			
				call		ReadROM				; display current hour expiry
				call		PrintBCD
				incf		addr, f

				movlw		":"
				call		WrtLCD

				call		ReadROM				; display current minute expiry
				call		PrintBCD
				incf		addr, f

				movlw		":"
				call		WrtLCD

				call		ReadROM				; display current second expiry
				call		PrintBCD
				incf		addr, f
			
SetExpiry		movfw		child_addr		
				movwf		addr
						
				call		Line1LCD
	
				call 		GetNum				; get month
				call		WrtROM
				incf		addr, f
		
				movlw 		"/"
				call 		WrtLCD
		
				call 		GetNum				; get date
				call		WrtROM
				incf		addr, f
	
				movlw 		"/"
				call 		WrtLCD
	
				call 		GetNum				; get year
				call		WrtROM
				incf		addr, f

				call		Line2LCD
	
				call 		GetNum				; get hour
				call		WrtROM
				incf		addr, f
	
				movlw 		":"
				call 		WrtLCD
	
				call 		GetNum				; get minute
				call		WrtROM
				incf		addr, f
	
				movlw 		":"
				call 		WrtLCD
		
				call 		GetNum				; get seond
				call		WrtROM
				incf		addr, f

				return

;}


;----[ ASSIGN MODULES ]-------------------------------------------------------------------------;

;{

;DESCRIPTION:		Assigns modules from admin->users or users->guests
;INPUT REGISTERS:	parent_access, child_access
;OUTPUT REGISTERS:	None
	
AssignModule	movlw		xModConfig			; get current active modules
				movwf		addr
				call		ReadROM
				movwf		modconfig

				movlw		2					; module x = xth bit of modconfig
				movwf		module_sel
				movlw		xMod1ID
				movwf		addr
				movlw		1
				movwf		order		
		
AssignLoop		btfss		module_sel, 0		; check if back screen
				goto		AssignMod
				call		ClrLCD
				call		Done
				call		Line2LCD
				call		YesOpt
				movlw		1
				movwf		check
				goto		Assign_Input

AssignMod		call		ClrLCD				; print module number

				call		Module
				call		PrintSpace
				call		Enumerate
				call		PrintSpace
		
				movfw		modconfig
				andwf		module_sel, w
				movwf		check
				incf		check, f
				decfsz		check, f
				goto		$+2
				goto		AssignDeny			; module not setup

				movfw		parent_access		
				andwf		module_sel, w
				movwf		check
				incf		check, f
				decfsz		check, f
				goto		$+2
				goto		AssignDeny			; parent does not have module access
		
				call		PrintName
				call		Line2LCD
		
				movfw		child_access		; see if child already has access
				andwf		module_sel, w
				movwf		mod_bit
				incf		mod_bit, f
				decfsz		mod_bit, f
				goto		OldAssign
		
				call		AssignOpt
				goto		Assign_Input
		
OldAssign		call		RemoveOpt			; display remove option
				goto		Assign_Input

AssignDeny		call		Denied				; display denied message
				call		Line2LCD
				call		NullOpt
			

Assign_Input	call		KPScroll			; poll for input
				movwf		key_no
				btfsc		key_no, 0
				goto		AIRightCirc
				btfsc		key_no, 1
				goto		AIDo_Opt
				goto		AILeftCirc

AIDo_Opt		btfsc		module_sel, 0		; back screen? save changes
				goto		AISave
				incf		check, f
				decfsz		check, f
				goto		AICheck				; ok to assign/remove modules
				goto		Assign_Input		; access was denied - no changes
			
AICheck			incf		mod_bit, f
				decfsz		mod_bit, f
				goto		AIDel				; already assigned - delete module
				goto		AIAdd				; add module
			
AIAdd			movfw		module_sel			; update child_access
				iorwf		child_access, f
				goto		AssignLoop
			
AIDel			comf		module_sel, w		; update child_access
				andwf		child_access, f
				goto		AssignLoop

AISave			movfw		child_access		; save assignment settings
				movwf		value	
				movfw		child_addr
				movwf		addr
				call		WrtROM
				return

AIRightCirc		incf		order, f			; next assign module screen
				movlw		2
				addwf		addr, f

				bcf			STATUS, C
				rlf			module_sel, f
				btfss		module_sel, 6
				goto		AssignLoop
				movlw		B'00000001'
				movwf		module_sel

				movlw		0
				movwf		order
				movlw		xMod1ID
				movwf		addr
				movlw		2
				subwf		addr, f
				goto		AssignLoop
				
AILeftCirc		decf		order, f			; previous assign module screen
				movlw		2
				subwf		addr, f

				bcf			STATUS, C
				rrf			module_sel, f
				btfss		STATUS, C
				goto		AssignLoop
				movlw		B'00100000'
				movwf		module_sel
		
				movlw		5
				movwf		order
				movlw		xMod5ID
				movwf		addr
				goto		AssignLoop

;}


;----[ OPEN MODULES ]---------------------------------------------------------------------------;

;{

;DESCRIPTION:		Open module menu for admin, users and guests
;INPUT REGISTERS:	access, curlog, LogAddr
;OUTPUT REGISTERS:	None

Do_Open			movlw		xModConfig			; get current system status
				movwf		addr
				call		ReadROM
				movwf		modconfig

				movlw		2					; xth module = xth bith of modconfig
				movwf		module_sel
				movlw		xMod1ID
				movwf		addr
				movlw		1
				movwf		order
				
OpenLoop		btfss		module_sel, 0		; back screen or module screen
				goto		ModList
				call		ClrLCD
				call		Back
				call		Line2LCD
				call		YesOpt
				movlw		1
				movwf		check
				goto		Open_Input

ModList			call		ClrLCD				; print module number

				call		Module
				call		PrintSpace
			
				call		Enumerate
				call		PrintSpace
		
				movfw		modconfig		
				andwf		module_sel, w
				movwf		check
				incf		check, f
				decfsz		check, f
				goto		$+2
				goto		OpenDeny			; module not set-up - deny access

				movfw		access			
				andwf		module_sel, w
				movwf		check
				incf		check, f
				decfsz		check, f
				goto		$+2
				goto		OpenDeny			; unauthorized - deny access
			
				call		PrintName			; access granted - print name
				call		Line2LCD
				call		OpenOpt
				goto		Open_Input			; print open option
	
OpenDeny		call		Denied				; print denied option
				call		Line2LCD	
				call		NullOpt

Open_Input		call		KPScroll			; poll for input
				movwf		key_no
				btfsc		key_no, 0
				goto		ORightCirc			; next open module screen
				btfsc		key_no, 1
				goto		ODo_Opt				; branch to sub-menu
				goto		OLeftCirc			; previous open module screen

ODo_Opt			btfss		module_sel, 0		; back screen? save settings
				goto		ODo_Open
				movfw		PWAddr
				movwf		addr
				return
			
ODo_Open		incf		check, f
				decfsz		check, f
				call		OpenModule			; access ok - open module
				goto		OpenLoop			; access denied- invalid input

ORightCirc		incf		order, f			; next open module screen
				movlw		2
				addwf		addr, f

				bcf			STATUS, C
				rlf			module_sel, f
				btfss		module_sel, 6
				goto		OpenLoop
				movlw		B'00000001'
				movwf		module_sel

				movlw		0
				movwf		order
				movlw		xMod1ID
				movwf		addr
				movlw		2
				subwf		addr, f
				goto		OpenLoop
				
OLeftCirc		decf		order, f			; previous open module screen
				movlw		2
				subwf		addr, f

				bcf			STATUS, C
				rrf			module_sel, f
				btfss		STATUS, C
				goto		OpenLoop
				movlw		B'00100000'
				movwf		module_sel

				movlw		5
				movwf		order
				movlw		xMod5ID
				movwf		addr
				goto		OpenLoop	


OpenModule	

				btfsc		PORTA, 0
				goto		PowerOn

				call		ClrLCD
				call		CursorOff
				call		Denied
				call		Line2LCD
				call		LowPower
			
				call		HumanDelay
				call		CursorOn
				return

PowerOn			incfsz		access, w			; get current if not admin
				call		GetTime

				pagesel		OpenRoutine
				call		StopSlave			; stop I2C (using Port C)
				call		OpenRoutine			; interact with maching
				call		StartSlave			; restart I2C
				pagesel		OpenModule
			
				incfsz		access, w			; generate log if not admin
				call		GenLog
			
				decfsz		long, f
				return
				goto		Standby	
			
;}


;----[ SYSTEM LOGS ]----------------------------------------------------------------------------;

;{
	
;DESCRIPTION:		Generates logs for users/guests
;INPUT REGISTERS:	LogAddr, curlog, hour, minute, second, month, date, year
;OUTPUT REGISTERS:	None
	
GenLog			movlw		RTC_Hour			; get current hour
				movwf		RTC_addr
				call		ReadRTC
				call		ClockEncode
				movfw		clockvalue
				movwf		ehour
			
				movlw		RTC_Minute			; get current minute
				movwf		RTC_addr
				call		ReadRTC
				call		ClockEncode
				movfw		clockvalue
				movwf		eminute		

				movlw		RTC_Second			; get current second
				movwf		RTC_addr
				call		ReadRTC
				call		ClockEncode
				movfw		clockvalue
				movwf		esecond
		
				movfw		addr
				movwf		modaddr
			
				movfw		curlog				; no logs yet - initialize pointer
				subwf		LogAddr, w
	
				btfsc		STATUS, Z
				incf		curlog, f
						
				movfw		curlog
				movwf		addr
			
				movfw		month				; save month
				movwf		value
				call		WrtROM
				incf		addr, f

				movfw		date				; save date
				movwf		value
				call		WrtROM
				incf		addr, f

				movfw		year				; save year
				movwf		value
				call		WrtROM
				incf		addr, f

				movfw		hour				; save hour
				movwf		value
				call		WrtROM
				incf		addr, f
			
				movfw		minute				; save minute
				movwf		value
				call		WrtROM
				incf		addr, f	
			
				movfw		IDAddr
				addlw		2
				subwf		PWAddr, w
				btfss		STATUS, Z
				goto		$+3
				clrw
				goto		$+2
				movlw		128
			
				iorwf		modaddr, w			; save name address of module opened
				movwf		value
				call		WrtROM
				incf		addr, f
			
				pagesel		Elapsed
				call		Elapsed				; get elapsed time
				pagesel		GenLog

				movfw		duration			; save elapsed time
				movwf		value
				
				call		WrtROM
				incf		addr, f

				movlw		7
				addwf		curlog, w
				movwf		curlog
				movwf		temp
			
				movfw		LogAddr
				addlw		35
				subwf		temp, f				; end of log list - cycle back
				decfsz		temp, f
				goto		$+4
				movfw		LogAddr
				addlw		1
				movwf		curlog
			
				movfw		curlog				; save pointer to next log
				movwf		value
				movfw		LogAddr
				movwf		addr
			
				call		WrtROM
						
				movfw		modaddr
				movwf		addr
			
				return

;DESCRIPTION:		Allows admin to view log for User X
;INPUT REGISTERS:	LogAddr, curlog
;OUTPUT REGISTERS:	None

Do_AccessLog	movfw		order
				movwf		orig_order
			
				movlw		1
				movwf		order

				movfw		addr
				movwf		child_addr

				movfw		LogAddr				; get current point
				movwf		addr
				call		ReadROM
				movwf		addr
			
				subwf		LogAddr, w
				btfss		STATUS, Z
				goto		$+2
				goto		NoLog				; is log emptry
				movlw		7
				subwf		addr, f
						
				movfw		LogAddr				; if not go to latest entry
				subwf		addr, w
				btfsc		STATUS, C
				goto		LogLoop
				movfw		LogAddr				; if we're at the start, go to end
				addlw		29
				movwf		addr
				goto		LogLoop
			
NoLog			incf		LogAddr, w			; dummy pointer
				movwf		addr

LogLoop			call		ClrLCD				; list log number
				call		Enumerate
			
				movfw		addr
		
				call		ReadROM				; is entry empty
				movwf		temp
				incfsz		temp, f				; if so skip the stats
				goto		PrintStats
			
				call		PrintSpace			; print empty, and goto input
				call		Empty
				call		Line2LCD
				call		NullOpt
				movlw		7
				addwf		addr, f
				goto		Log_Input
			
PrintStats		call		ReadROM				; print month
				call		PrintBCD
				incf		addr, f

				movlw		"/"	
				call		WrtLCD		
	
				call		ReadROM				; print date
				call		PrintBCD
				incf		addr, f

				movlw		"/"
				call		WrtLCD

				call		ReadROM				; print year
				call		PrintBCD
				incf		addr, f

				call		PrintSpace

				call		ReadROM				; print hour
				call		PrintBCD
				incf		addr, f

				movlw		":"
				call		WrtLCD

				call		ReadROM				; print minute
				call		PrintBCD
				incf		addr, f

				call		Line2LCD
			
				movlw		127
				call		WrtLCD
				call		PrintSpace
				
				movfw		addr
				movwf		tempaddr
				
				call		ReadROM				; print name of opened module
				movwf		addr
				btfss		addr, 7
				movlw		"U"
				btfsc		addr, 7
				movlw		"G"
				call		WrtLCD
				call		PrintSpace
				movlw		b'01111111'
				andwf		addr, f
				call		PrintName
				call		PrintSpace
			
				movfw		tempaddr
				movwf		addr
				incf		addr, f
			
				call		ReadROM
				movwf		duration
			
				movlw		16					; get duration
				addwf		duration, w
				btfsc		STATUS, C
				goto		TooLong				; check if > 4 minutes
			
				pagesel		GetElapsed
				call		GetElapsed			; get elpased time (bin to dec)
				pagesel		PrintStats

			
PrintElapsed	call		PrintSpace
			
				movfw		hundred		
				addlw		48
				call		WrtLCD
				
				movfw		ten
				addlw		48
				call		WrtLCD
	
				movfw		one		
				addlw		48
				call		WrtLCD
			
				goto		LogPrint
				
TooLong			movlw		">"					; too long? print > than 240 seconds
				call		WrtLCD
				movlw		"2"
				call		WrtLCD
				movlw		"4"
				call		WrtLCD
				movlw		"0"
				call		WrtLCD
			
			
LogPrint		movlw		"s"
				call		WrtLCD
				call		PrintSpace
				movlw		126
				call		WrtLCD

				incf		addr, f

Log_Input		call		KPScroll			; poll for input
				movwf		key_no
				btfsc		key_no, 0
				goto		LRightCirc			; older log
				btfsc		key_no, 1
				goto		LDo_Opt				; branch to sub-menu
				goto		LLeftCirc			; newer log

LDo_Opt			movfw		child_addr			; go back if at back screen
				movwf		addr
				movfw		orig_order
				movwf		order
				goto		UserManage

LRightCirc		movlw		5					; goto older log
				subwf		order, w
				btfsc		STATUS, Z
				clrf		order
				incf		order, f
		
				movlw		14
				subwf		addr, f
		
				movfw		LogAddr
				subwf		addr, w
				btfsc		STATUS, C		
				goto		LogLoop
				movfw		LogAddr
				addlw		29
				movwf		addr
				goto		LogLoop
		
LLeftCirc		movlw		5					; goto newer log
				decf		order, f
				btfsc		STATUS, Z
				movwf		order
			
				movfw		LogAddr
				addlw		36
				subwf		addr, w
				btfss		STATUS, Z
				goto		LogLoop
				movfw		LogAddr
				movwf		addr
				incf		addr, f
				goto		LogLoop

;}


;----[ MISCELLANEOUS FUNCTIONALITIES ]----------------------------------------------------------;

;{
	
;DESCRIPTION:		Allows user/administrator to change password
;INPUT REGISTERS:	PWAddr
;OUTPUT REGISTERS:	None

Do_ChangePW		movfw		PWAddr				; get address to save password
				movwf		addr	

				call		ClrLCD				; prompt for password
				call		Password
				call		Line2LCD
		
				call		GetFour
				call		StoreFour

				return

;DESCRIPTION:		Allows administrator to reset system (logs, account, modules)
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None

Do_ResetSystem	movlw		xRestart
				movwf		addr
				movlw		255
				movwf		value
				call		WrtROM
			
				goto		InitSystem

;DESCRIPTION:		Allows administrator to adjust date/time display
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None

Do_AdjDT		call		ClrLCD
				call		DatePrompt
				
				call		Line2LCD
				call		TimePrompt
				
				call		Line1LCD
	
				movlw 		RTC_Month			; get month
				movwf 		field
				call 		GetNum	
				call		WriteRTC
		
				movlw 		"/"
				call 		WrtLCD
		
				movlw 		RTC_Date			; get date
				movwf 		field
				call 		GetNum
				call		WriteRTC
	
				movlw 		"/"
				call 		WrtLCD
	
				movlw 		RTC_Year			; get year
				movwf 		field
				call 		GetNum
				call		WriteRTC

				call		Line2LCD

				movlw 		RTC_Hour			; get hour
				movwf 		field
				call 		GetNum
				call		WriteRTC
	
				movlw 		":"
				call 		WrtLCD
	
				movlw 		RTC_Minute			; get minute
				movwf 		field
				call 		GetNum
				call		WriteRTC
	
				movlw 		":"
				call 		WrtLCD
		
				movlw 		RTC_Second			; get second
				movwf 		field
				call 		GetNum
				call		WriteRTC

				goto 		AdmLoop

;}


;----[ CLOCK FUNCTIONS ]------------------------------------------------------------------------;

;{
	
;DESCRIPTION:		Tranmit data through I2C bus
;INPUT REGISTERS:	field, value
;OUTPUT REGISTERS:	none
	
WriteRTC		rtc_set 	field, value
				banksel 	0x00
				return

;DESCRIPTION:		Upload data through I2C bus
;INPUT REGISTERS:	RTC_addr
;OUTPUT REGISTERS:	dig10, dig1

ReadRTC			rtc_read	RTC_addr
				banksel		0x00
				return

;DESCRIPTION:		Converts 2-byte ASCII value to 1-byte binary
;INPUT REGISTERS:	dig10, dig1
;OUTPUT REGISTERS:	clockvalue

ClockEncode		movlw		48					; tens digit = upper nibble
				subwf		dig10, w
				andlw		0x0F
				movwf		clockvalue
				swapf		clockvalue, f

				movlw		48					; ones digit = lower nibble
				subwf		dig1, w
				andlw		0x0F
				addwf		clockvalue, f
				return

;DESCRIPTION:		Get date and time from RTC chip
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	hour, minute, second, month, date, year

GetTime			movlw		RTC_Hour			;get current hour
				movwf		RTC_addr
				call		ReadRTC
				call		ClockEncode
				movfw		clockvalue
				movwf		hour
			
				movlw		RTC_Minute			;get current minute
				movwf		RTC_addr
				call		ReadRTC
				call		ClockEncode
				movfw		clockvalue
				movwf		minute		

				movlw		RTC_Second			; get current second
				movwf		RTC_addr
				call		ReadRTC
				call		ClockEncode
				movfw		clockvalue
				movwf		second

				movlw		RTC_Month			; get current month
				movwf		RTC_addr
				call		ReadRTC	
				call		ClockEncode
				movfw		clockvalue
				movwf		month

				movlw		RTC_Date			; get current date
				movwf		RTC_addr
				call		ReadRTC
				call		ClockEncode
				movfw		clockvalue
				movwf		date

				movlw		RTC_Year			; get current year
				movwf		RTC_addr
				call		ReadRTC			
				call		ClockEncode
				movfw		clockvalue
				movwf		year

				return

;}


;----[ LCD FUNCTIONS ]--------------------------------------------------------------------------;

;{
	
;DESCRIPTION:		Initialize the LCD
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None
	
InitLCD			
				banksel		PORTD
	
				call 		LongDelay			; wait for LCD POR to finish (~15ms)
				call 		LongDelay
				call 		LongDelay

				movlw		B'00110011'
				call		WrtIns				; ensure 8-bit mode first
				call 		LongDelay

				movlw		B'00110010'
				call		WrtIns
				call 		LongDelay

		 		movlw		B'00101000' 		; 4 bits, 2 lines,5X8 dot
				call		WrtIns
				call 		LongDelay
			
				call		CursorOn			; turn on cursor

				movlw 		B'00000110' 		; increment cursor without shifting screen
				call		WrtIns		
				call 		LongDelay

				call		ClrLCD				; clear screen
		
				return
 	
;DESCRIPTION:		Clears the LCD
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None 
 
ClrLCD			movlw		B'00000001'			; command for clearing LCD RAM
				call		WrtIns
				call 		LongDelay

				return

;DESCRIPTION:		Writes literal characters to the LCD
;INPUT REGISTERS:	w
;OUTPUT REGISTERS:	None 

WrtLCD			movwf		lcd_tmp				; store character to be printed
				call		MovMSB 				; move MSB to PORTD
				call		E_Pulse				; pulse enable
				swapf		lcd_tmp,w 			; move LSB to PORTD
				call		MovMSB    
				call		E_Pulse				; pulse clock
				return

;DESCRIPTION:		Pulses line low and high to transmit data
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None 

E_Pulse			call		ShortDelay							
    			bcf 		PORTD,E				; set enable low
    			call		ShortDelay   
    			bsf 		PORTD,E    			; set enable high
    			return

;DESCRIPTION:		Transmits upper nibble then lower nibble
;INPUT REGISTERS:	w
;OUTPUT REGISTERS:	None 

MovMSB			andlw 		0xF0				; clear 4 LSBs
				iorwf		PORTD,f				; move into PORTD
				iorlw		0x0F				; clear 4 MSBs	
				andwf		PORTD,f				; move into PORTD
				return

;DESCRIPTION:		Move cursor to Line 1
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None 

Line1LCD		movlw		B'10000000'			; command for moving to line 1
				call		WrtIns
				call 		LongDelay
				return

;DESCRIPTION:		Move cursor to Line 2
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None 

Line2LCD		movlw		B'10101000'			; command for moving to line 2
				call		WrtIns
				call 		LongDelay
				return

;DESCRIPTION:		Turn cursor on
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None 

CursorOn		movlw		B'00001111' 		; display on, cursor on, blink on
				call		WrtIns
				call		LongDelay

				return

;DESCRIPTION:		Turn cursor off
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None 

CursorOff		movlw   	B'00001100'   		; display on, cursor off, blink off
         	 	call     	WrtIns
				call		LongDelay
		  		return

;DESCRIPTION:		Sends command to LCD
;INPUT REGISTERS:	w
;OUTPUT REGISTERS:	None 

WrtIns			bcf			PORTD, RS			; instruction mode
				call		WrtLCD				; write instruction
				bsf			PORTD, RS			; data mode
			
				return
			
;}


;----[ DELAY FUNCTIONS ]------------------------------------------------------------------------;

;{

;DESCRIPTION:		Delay for 750 ms
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None 	
	
HumanDelay		movlw		150
				movwf		delay3
			
HD_Loop			call		LongDelay
				decfsz		delay3, f
				goto		HD_Loop
			
				return

;DESCRIPTION:		Delay for 5 ms
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None

LongDelay		movlw		20					
   				movwf 		delay2				
   			
LD_Loop			call		ShortDelay			
    			decfsz 		delay2,f
    			goto		LD_Loop
    			
    			return

;DESCRIPTION:		Delay for 160 us
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None

ShortDelay		movlw		0xFF					
				movwf		delay1					
				decfsz		delay1,f
				goto    	$-1
			
				return
			
;}
	
			
;----[ INPUT FUNCTIONS ]------------------------------------------------------------------------;

;{

;DESCRIPTION:		Poll for input from keypad and log out if more than 60 secods
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	w	
	
KPGetChar		movlw		RTC_Second			; get starting time second
				movwf		RTC_addr
				call		ReadRTC
				call		ClockEncode
				decf		clockvalue, w		; subtract 1
				movwf		second
				incf		second, w
				btfss		STATUS, Z
				goto		Polling
				movlw		59					; if 0 then make it 59
				movwf		second

Polling			movlw		RTC_Second			; get current second
				movwf		RTC_addr
				call		ReadRTC
				call		ClockEncode
				movfw		clockvalue
				subwf		second, w			; check if its same as starting
				btfsc		STATUS, Z
				goto		Standby				; if so logout
				clrw
				btfss		PORTB,1     		; wait until data from keypad input
				goto		Polling				; keep updating elapsed time
				swapf		PORTB,W    			; read PortB<7:4> into W<3:0>
				andlw		0x0F				; clear W<7:4>
				btfsc		PORTB,1     		; wait until key is released
				goto		$-1

				return

;DESCRIPTION:		Converts binary keypad values to ASCII
;INPUT REGISTERS:	w
;OUTPUT REGISTERS:	w

KPHexToChar		PCLSwitch	AlphaNum
AlphaNum		dt			"123A456B789C*0#D", 0

;DESCRIPTION:		Gets input for menu scrolling ('#', '0', '*')
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	w

KPScroll		call		KPGetChar			; get input
				movwf		key_no
				incf		key_no, f
				btfsc		key_no, 4
				goto		KPScroll

				incf		key_no, f
				btfsc		key_no, 4
				retlw		1					; is it '#' (next)
			
				incf		key_no, f
				btfsc		key_no, 4
				retlw		2					; is it '0' (do)
			
				incf		key_no, f		
				btfsc		key_no, 4
				retlw		4					; is it '*' (prev)
			
				goto		KPScroll			; invalid input

;DESCRIPTION:		Gets alphanumeric input (everything except *, #)
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	w

KPGetAlphaNum	call		KPGetChar			; get input
				movwf		kp_tmp
				movlw		0x0E
				xorwf		kp_tmp, w
				btfsc		STATUS, Z
				goto		KPGetAlphaNum		; try again if '#'
			
				clrf		kp_ret
				movlw		0x0C
				xorwf		kp_tmp, w
				btfsc		STATUS, Z
				return
			
				incf		kp_ret, f
				movfw		kp_tmp
				call		KPHexToChar
				call		WrtLCD
				return

;DESCRIPTION:		Gets and prints two characters and returns one binary byte
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	value

GetFour			call		KPGetAlphaNum		; get input
				movfw		kp_ret
				btfsc		STATUS, Z
				goto		GetFour
			
				movfw		kp_tmp
				movwf		kp_tmp1
			
Char2			call		KPGetAlphaNum		; get input
				movfw		kp_ret
				btfss		STATUS, Z
				goto		$+4
				movlw		b'00010000'
				call		WrtIns
				goto		GetFour
			
				movfw		kp_tmp
				movwf		kp_tmp2
			
Char3			call		KPGetAlphaNum		; get input
				movfw		kp_ret
				btfss		STATUS, Z
				goto		$+4
				movlw		b'00010000'
				call		WrtIns
				goto		Char2
			
				movfw		kp_tmp
				movwf		kp_tmp3
			
				call		KPGetAlphaNum		; get input
				movfw		kp_ret
				btfss		STATUS, Z
				goto		$+4
				movlw		b'00010000'
				call		WrtIns
				goto		Char3
			
				movfw		kp_tmp
				movwf		kp_tmp4
									
				swapf		kp_tmp1, w
				iorwf		kp_tmp2, w
				movwf		char1
			
				swapf		kp_tmp3, w
				iorwf		kp_tmp4, w
				movwf		char2

				return

;DESCRIPTION:		Gets one digit and displays it on LCD
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	comp

GetDigit		call		KPGetChar			; get input
				call		KPHexToChar			; convert to ASCII

				movwf		temp
				btfss 		temp, 4			
				goto 		GetDigit			; '#' or '*' - try again
			
				movwf 		comp
				movlw 		0x3A
				subwf 		comp, f
				btfss 		comp,7			
				goto 		GetDigit			; a letter not number - try again
			
				movfw 		temp				; print number
				call 		WrtLCD
				movfw 		comp
				addlw 		0x0A
				movwf 		comp

				return

;DESCRIPTION:		Gets two digit number and packs it in one binary byte
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	value

GetNum			call 		GetDigit
				swapf 		comp, w
				movwf 		value
				call 		GetDigit
				addwf 		value, f
				return
			
;}


;----[ OUTPUT FUNCTIONS ]-----------------------------------------------------------------------;

;{

;DESCRIPTION:		Prints "X: " for given X 
;INPUT REGISTERS:	order
;OUTPUT REGISTERS:	None	
	
Enumerate		movfw		order
				addlw		48
				call		WrtLCD
				movlw		":"
				call		WrtLCD	
			
				return

;DESCRIPTION:		Prints a space 
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None	

PrintSpace		movlw		" "
				call		WrtLCD
				return

;DESCRIPTION:		Prints one keypad encoded byte as two ASCII characters
;INPUT REGISTERS:	w
;OUTPUT REGISTERS:	None	

PrintASCII		movwf		value				; print first character
				swapf		value, w
				andlw		0x0F
				call		KPHexToChar
				call		WrtLCD

				movfw		value				; print second character
				andlw		0x0F
				call		KPHexToChar
				call		WrtLCD

				return	

;DESCRIPTION:		Prints one binary byte as two ASCII numerals
;INPUT REGISTERS:	w
;OUTPUT REGISTERS:	None	

PrintBCD		movwf		temp				; print first numeral
				swapf		temp, w
				andlw		0x0F
				addlw		48
				call		WrtLCD
			
				movfw		temp				; print second numeral
				andlw		0x0F
				addlw		48
				call		WrtLCD

				return

;DESCRIPTION:		Prints four character name (ID/PW/module)
;INPUT REGISTERS:	addr
;OUTPUT REGISTERS:	None	

PrintName		call		ReadROM				; get first encoded byte
				call		PrintASCII
				incf		addr, f
				call		ReadROM				; get second encoded byte
				call		PrintASCII
				decf		addr, f

				return

;DESCRIPTION:		Retrieves and displays date on LCD
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None	

PrintDate		movlw		RTC_Month			; print month
				movwf		RTC_addr
				call		ReadRTC
				call 		DisplayRTC

				movlw 		"/"
				call 		WrtLCD

				movlw		RTC_Date			; print date
				movwf		RTC_addr
				call		ReadRTC
				call 		DisplayRTC

				movlw 		"/"
				call 		WrtLCD

				movlw		RTC_Year			; print year
				movwf		RTC_addr
				call		ReadRTC
				call 		DisplayRTC

				return

;DESCRIPTION:		Retrieves and displays time on LCD
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None	

PrintTime		movlw		RTC_Hour			; print hour
				movwf		RTC_addr
				call		ReadRTC
				call 		DisplayRTC

				movlw 		":"
				call 		WrtLCD

				movlw		RTC_Minute			; print minute
				movwf		RTC_addr
				call		ReadRTC
				call 		DisplayRTC

				movlw 		":"
				call 		WrtLCD

				movlw		RTC_Second			; print second
				movwf		RTC_addr
				call		ReadRTC
				call 		DisplayRTC

				return

;DESCRIPTION:		Displays 10 and 1 digit from clock to LCD
;INPUT REGISTERS:	dig10, dig1
;OUTPUT REGISTERS:	None	

DisplayRTC 		movfw 		dig10				; display tens digit
		  		call 		WrtLCD
		  		movfw 		dig1				; display ones digit
		 		call 		WrtLCD
		 		
		  		return

;DESCRIPTION:		Moves address of message into w and goes to right table
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None	

AdminID			movlw		0
				goto		Message1Disp
AdminPW			movlw		14
				goto		Message1Disp
UserID			movlw		28
				goto		Message1Disp
Password		movlw		38
				goto		Message1Disp	
ModID			movlw		54
				goto		Message1Disp
PCInterface		movlw		71
				goto		Message1Disp
Configure		movlw		84
				goto		Message1Disp
ManageAcc		movlw		94
				goto		Message1Disp	
AssignModules	movlw		110
				goto		Message1Disp
ExpiryPrompt	movlw		125
				goto		Message1Disp
OpenMod			movlw		136
				goto		Message1Disp
AdjDT			movlw		148
				goto		Message1Disp
DatePrompt		movlw		165
				goto		Message1Disp
TimePrompt		movlw		174
				goto		Message1Disp
ChangePW		movlw		183
				goto		Message1Disp
ResetSystem		movlw		199
				goto		Message1Disp
Edit 			movlw		212
				goto		Message1Disp
Log				movlw		217
				goto		Message1Disp
GuestActive		movlw		221
				goto		Message1Disp
GuestAcc		movlw		234
				goto		Message1Disp
Welcome			movlw		248
				goto		Message1Disp
Denied			movlw		0
				goto		Message2Disp
Empty			movlw		7
				goto		Message2Disp
Free			movlw		13
				goto		Message2Disp	
Delete			movlw		20
				goto		Message2Disp
Module			movlw		27
				goto		Message2Disp
User			movlw		34
				goto		Message2Disp
Press			movlw		39
				goto		Message2Disp
AnyKey			movlw		45
				goto		Message2Disp
LowPower		movlw		55
				goto		Message2Disp	
Unlocked		movlw		65
				goto		Message2Disp	
ModuleOpened	movlw		76
				goto		Message2Disp	
Obstructed		movlw		93
				goto		Message2Disp
YesOpt			movlw		110
				goto		Message2Disp			
AddOpt			movlw		127
				goto		Message2Disp
OpenOpt			movlw		144
				goto		Message2Disp
DelOpt			movlw		161
				goto		Message2Disp
RemoveOpt		movlw		178
				goto		Message2Disp
AssignOpt		movlw		195
				goto		Message2Disp
ManageOpt		movlw		212
				goto		Message2Disp																		
Back			movlw		229
				goto		Message2Disp
Done			movlw		235
				goto		Message2Disp
Logoff			movlw		241
				goto		Message2Disp			
Skip			movlw		249
				goto		Message2Disp

NullOpt			movlw		127
				call		WrtLCD
				movlw		14
				movwf		count
				call		PrintSpace
				decfsz		count, f
				goto		$-2
				movlw		126
				call		WrtLCD
			
				return
						
;DESCRIPTION:		Offsets w from correct table
;INPUT REGISTERS:	w
;OUTPUT REGISTERS:	None	

Message1Disp	WRT_STR		Message1			; print from "Messages1" table
				return
			
Message2Disp	WRT_STR		Message2			; print from "Messages2" table
				return
			
;}


;----[ EEPROM FUNCTIONS ]-----------------------------------------------------------------------;

;{
	
;DESCRIPTION:		Writes data to EEPROM
;INPUT REGISTERS:	addr, value
;OUTPUT REGISTERS:	None	
	
WrtROM			movfw		addr

				banksel		EEADR				; set address
				movwf		EEADR

				banksel		value
				movfw		value

				banksel		EEDATA				; set value
				movwf		EEDATA
	
				banksel		EECON1				; standard write sequence
				bcf			EECON1, EEPGD
				bsf			EECON1, WREN
				movlw		0x55
				movwf		EECON2
				movlw		0xAA
				movwf		EECON2
				bsf			EECON1, WR
				bcf			EECON1, WREN
				btfsc		EECON1, WR
				goto		$-1

				banksel		addr
		
				return

;DESCRIPTION:	 	Reads data from EEPROM
;INPUT REGISTERS:	addr
;OUTPUT REGISTERS:	w	

ReadROM			movfw		addr
	
				banksel		EEADR				; set address
				movwf		EEADR

				banksel		EECON1				; standard read sequence
				bcf			EECON1, EEPGD
				bsf			EECON1, RD

				banksel		EEDATA				; get data
				movfw		EEDATA

				banksel		addr
			
				return
	
;DESCRIPTION:	 	Compares if contents of value are same as in EEPROM addr
;INPUT REGISTERS:	addr
;OUTPUT REGISTERS:	w		
		
CheckROM		call		ReadROM				; get data

				subwf		value, f			; get difference
				incf		value, f
				decfsz		value, f
				retlw		0					; different values
				retlw		1					; same value

StoreFour		movfw		char1
				movwf		value
				call		WrtROM
			
				incf		addr, f
				movfw		char2
				movwf		value
				call		WrtROM
			
				return

;}


Page1			org			0x800

;----[ TABLES ]---------------------------------------------------------------------------------;

;{

;DESCRIPTION:	 	Table of messages
;INPUT REGISTERS:	N/A
;OUTPUT REGISTERS:	N/A

Message1		PCLSwitch	Table1				; change pages if 256 byte boundary
							; "Message", end of str			;start length
Table1			dt			"Set Admin ID:", 0				;0		14
				dt			"Set Admin PW:", 0				;14		14
				dt			"Enter ID:", 0					;28		10
				dt			"Enter Password:", 0  			;38		16
				dt			"Enter Module ID:", 0			;54		17
				dt			"PC Interface", 0				;71		13
				dt			"Configure", 0					;84		10
				dt			"Manage Accounts", 0			;94		16
				dt			"Assign Modules", 0				;110	15
				dt			"Set Expiry", 0					;125	11	
				dt			"Open Module", 0				;136	12	
				dt			"Adjust Date/Time", 0			;148	17	
				dt			"MM/DD/YY", 0					;165	9
				dt			"HH:MM:SS", 0					;174	9				
				dt			"Change Password", 0			;183	16			
				dt			"Reset System", 0				;199	13
				dt			"Edit", 0						;212	5
				dt			"Log", 0						;217	4	
				dt			"Guest Active", 0				;221	13
				dt			"Guest Account", 0				;234	14
				dt			"Welcome", 0					;248	8	

Message2		PCLSwitch	Table2				; change pages if 256 byte boundary
							; "Message", end of str			;start length
Table2			dt			"Denied", 0						;0		7
				dt			"Empty", 0						;7		6				
				dt			"(Free)", 0						;13		7
				dt			"Delete", 0						;20		7
				dt			"Module", 0						;27		7
				dt			"User", 0						;34		5		
				dt			"Press", 0						;39		6
				dt			"Any Key..", 0					;45		10
				dt			"Low Power", 0					;55		10	
				dt			"Unlocked..", 0					;65		11		
				dt			"Module Opened...", 0			;76		17		
				dt			"Door Obstructed!", 0			;93		17
				dt			127, "    0--Yes    ", 126, 0	;110	17
				dt			127, "    0--Add    ", 126, 0	;127	17
				dt			127, "    0-Open    ", 126, 0	;144	17
				dt			127, "   0-Delete   ", 126, 0	;161	17		
				dt			127, "   0-Remove   ", 126, 0	;178	17
				dt			127, "   0-Assign   ", 126, 0	;195	17	
				dt			127, "   0-Manage   ", 126, 0	;212 	17		
				dt			"Back?", 0						;229 	6
				dt			"Done?", 0						;235	6
				dt			"Logoff?", 0					;241	8		
				dt			"Skip", 126, 0					;249	6

;}


; ---[ PORT FUNCTIONS ]-------------------------------------------------------------------------;

;{
	
;DESCRIPTION:	 	Initializes ports
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None
	
InitPort		clrf		INTCON         		; no interrupts
				banksel		PORTA				; clear all data latches
				clrf		PORTA
				clrf		PORTB
				clrf		PORTC
				clrf		PORTD
				clrf		PORTE


				banksel		ADCON1				; set port A as digital
				movlw		6
				movwf		ADCON1
				
				banksel		TRISA				; set port A as input
				movlw		b'00111111'
				movwf		TRISA
				movlw		b'11110010'    		; 4-bit keypad input
				movwf    	TRISB
				movlw		b'00011000'			; C<3:4> used by clock
				movwf		TRISC
				clrf     	TRISD          		; all port D is output
				clrf		TRISE				; don't need port E
		
				banksel		0x00

				return

;DESCRIPTION:	 	Ensure no data transmission occur on I2C bus
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None

I2C_Idle		btfsc		SSPSTAT, R_W    	; transmitting?
				goto		$-1             
			
				movfw		SSPCON2
				andlw		0x1F                 ; mask ACKEN, RCEN, PEN, RSEN, SEN
				btfss		STATUS, Z
				goto		$-3
			
				return

;DESCRIPTION:	 	Restarts I2C bus
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None

StartSlave
				banksel		TRISC				; initialize port c
				movlw		b'00011000'
				movwf		TRISC
			
				call		I2C_Idle			; make sure no data transmission
			
				movlw		b'00001000'     	; config SSP for Master Mode I2C
				banksel		SSPCON
    			movwf		SSPCON
    			bsf			SSPCON,SSPEN    	; enable SSP module
			
				banksel		SSPCON2				; enable repeated start bit
				bsf			SSPCON2,RSEN
				btfsc		SSPCON2,RSEN
				goto		$-1
				
				banksel		0
			
				return

;DESCRIPTION:	 	Disengages I2C bus
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None

StopSlave		call		I2C_Idle			; make sure no data transmission
			
				banksel		SSPCON2				; pause write enable
				bsf			SSPCON2,PEN
				btfsc		SSPCON2,PEN
				goto		$-1
			
				banksel		SSPCON				; disable SSP module
				clrf		SSPCON

				banksel		TRISC				; set up PORTC for output
				clrf		TRISC
				banksel	0

				return
			
;}


;----[ MACHINE INTERFACE ]----------------------------------------------------------------------;

;{
	
;DESCRIPTION:	 	Sends output signals to solenoids and gets input from sensors
;INPUT REGISTERS:	None
;OUTPUT REGISTERS:	None
	
OpenRoutine
				banksel		PORTC
				movfw		module_sel
				movwf		PORTC
				bsf			PORTC, 7			; unlock module
			
				pagesel		ClrLCD				; display unlocked message
				call		ClrLCD
				call		Unlocked
				pagesel		OpenRoutine
			
				clrf		long

				movlw		15					; wait three seconds
				movwf		delay1

Open1			movlw		255					
   				movwf 		delay2					

Open2			movlw		255						
				movwf		delay3				

Open3			movfw		module_sel
				andwf		PORTA, w			; microswitch opened
				btfss		STATUS, Z
				goto		DoorOpened
				decfsz		delay3,f
				goto    	Open3			
    			decfsz 		delay2,f
    			goto		Open2
				decfsz		delay1, f
				goto		Open1

				goto		DoneInteract		; door never opened - relock
	
DoorOpened		bcf			PORTC, 7			; door opened, relax lock
	
				pagesel		ClrLCD				; display opened message
				call		ClrLCD
				call		ModuleOpened
				pagesel		OpenRoutine
			
				incfsz		access, w			; if admin, keep open until button
				goto		JammedOpen
			
ForeverOpen		movfw		module_sel
				andwf		PORTA, w			; has button been pushed?
				btfsc		STATUS, Z
				goto		Confirm				; if so branch to confirm
				goto		ForeverOpen
		
JammedOpen		movlw		85					; wait for 15 seconds
				movwf		delay1	

Button1			movlw		255				
   				movwf 		delay2				

Button2			movlw		255						
				movwf		delay3					

Button3			movfw		module_sel
				andwf		PORTA, w			
				btfsc		STATUS, Z			; has button been pushed?
				goto		Confirm				; if so goto Confirm
				decfsz		delay3,f
				goto    	Button3			
    			decfsz 		delay2,f
    			goto		Button2
				decfsz		delay1, f
				goto		Button1
		
		
Confirm			bsf			PORTC, 6			; release door jammer
				pagesel		HumanDelay
				call		HumanDelay
				pagesel		OpenRoutine
				movfw		module_sel		
				andwf		PORTA, w
				btfsc		STATUS, Z			; is door still open/button pushed
				goto		Proceed			
					
DoorStuck	
				pagesel		ClrLCD				; if so, idle until user rectifies
				call		ClrLCD
				call		Obstructed
				pagesel		OpenRoutine
						
				movfw		module_sel
				andwf		PORTA, w
				btfss		STATUS, Z
				goto		$-3
			
Proceed		
				pagesel		ClrLCD				; system ready, wait for user to go
				call		ClrLCD
				call		Done
				call		Line2LCD
				call		Press
				call		PrintSpace	
				call		AnyKey
				pagesel		OpenRoutine
		
				movlw		225					; wait for 60 seconds
				movwf		delay1	

KP1				movlw		255				
   				movwf 		delay2				

KP2				movlw		255						
				movwf		delay3					

KP3				movfw		module_sel
				andwf		PORTA, w
				btfss		STATUS, Z
				goto		DoorStuck			; button pushed again or door opened
				btfss		PORTB, 1
				goto		TestDoor
				btfsc		PORTB, 1
				goto		$-1					; user acknowledges completion
				goto		DoneInteract

TestDoor		decfsz		delay3,f
				goto    	KP3			
    			decfsz 		delay2,f
    			goto		KP2
				decfsz		delay1, f
				goto		KP1
		
				incf		long, f

DoneInteract
				banksel		PORTC				; clear all solenoid output
				clrf		PORTC

				return	
			
;}


;----[ MATH FUNCTIONS ]-------------------------------------------------------------------------;

;{
	
;DESCRIPTION:	 	Converts a two-digit binary coded decimal number to binary
;INPUT REGISTERS:	comp
;OUTPUT REGISTERS:	comp
	
BCDToBinary		swapf		comp, w
				andlw		0x0F
				movwf		temp				; temp holds LSB of comb
				movlw		0x0F
				andwf		comp, f				; comp holds MSB
			
				bcf			STATUS, C		
				rlf			temp, f				; XY = 2(X)+8(X)+Y
				movfw		temp
				addwf		comp, f
				bcf			STATUS, C
				rlf			temp, f
				bcf			STATUS, C	
				rlf			temp, f
				movfw		temp
				addwf		comp, f
			
				return
	
;DESCRIPTION:	 	Calculates the elapsed time of module opening and clsoing
;INPUT REGISTERS:	second, esecond, minute, eminute, hour, ehour
;OUTPUT REGISTERS:	duration
	
Elapsed			clrf		duration

				movfw		second				; convert starting seconds to binary
				movwf		comp
				call		BCDToBinary
				movfw		comp
				movwf		second

				movfw		esecond				; convert ending seconds to binary
				movwf		comp
				call		BCDToBinary
				movfw		comp
				movwf		esecond

				movfw		minute				; convert starting minutes to binary
				movwf		comp
				call		BCDToBinary
				movfw		comp
				movwf		minute
			
				movfw		eminute				; convert ending minutes to binary
				movwf		comp
				call		BCDToBinary
				movfw		comp
				movwf		eminute
			
				movfw		hour				; convert starting hours to binary
				movwf		comp
				call		BCDToBinary
				movfw		comp
				movwf		hour
			
				movfw		ehour				; convert ending hours to binary
				movwf		comp
				call		BCDToBinary
				movfw		comp
				movwf		ehour
			
				movfw		second				; get difference between seconds
				subwf		esecond, f
						
				btfss		STATUS, C
				goto		$+2					; carry
				goto		$+9					; no carry
				movfw		eminute
				btfsc		STATUS, Z			; if subtrahend is 0, inc minuend
				goto		$+3
				decf		eminute, f			; else dec subtrahend
				goto		$+2
				incf		minute, f
				movlw		60					; add after carry
				addwf		esecond, f
		
				movfw		minute				; get difference between minutes
				subwf		eminute, f
			
				btfss		STATUS, C
				goto		$+2					; carry
				goto		$+4					; no carry
				decf		ehour, f			; decrease elapsed hours
				movlw		60
				addwf		eminute, f			; add after carry
						
				movlw		4				
				movwf		temp
				incf		eminute, f

FindMinutes		decfsz		eminute, f			; add 60 while elapsed time < 4 min
				goto		$+2
				goto		FindSeconds			; less than 4 minutes
				movlw		60
				addwf		duration, f
				decfsz		temp, f
				goto		FindMinutes
				return							; greater than 4 minutes
				
FindSeconds		movfw		esecond				; duration = 60*min + sec
				addwf		duration, f
		
				return
	
;DESCRIPTION:	 	Converts the elapsed time from binary to decimal values
;INPUT REGISTERS:	duration
;OUTPUT REGISTERS:	hundred, ten, one
			
GetElapsed		clrf		hundred
				clrf		ten
				clrf		one
			
				movlw		2				
				movwf		temp
			
HundredLoop		movlw		100					; count # of hundreds
				subwf		duration, w
				btfss		STATUS, C
				goto		TenLoop				; remaining less than 100 seconds
				movwf		duration
				incf		hundred, f
				goto		HundredLoop
			
TenLoop			movlw		10					; count # of tends
				subwf		duration, w
				btfss		STATUS, C
				goto		OneLoop				; remaining less than 10 seconds
				movwf		duration
				incf		ten, f
				goto		TenLoop
			
OneLoop			movfw		duration			; duration - 100*H - 10*T = One
				movwf		one
		
				return
	
;}
			
	
				end
