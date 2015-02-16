.include ppcdefines.i

.global PPCCode,PPCLen

.set	PPCLen,(PPCEnd-PPCCode)

#********************************************************************************************
	
	.text
PPCCode:
	b  system_reset				#Branch outside table

	.space 0x400-12				#$500	External Interrupt
Halt1:	ori	r0,r0,0		         	#no-op
	b	Halt1
	
#********************************************************************************************
		

EInt:	mtspr	SPRG0,r3			#Redo save state sometime....(stack?)
	mtspr	SPRG1,r4
	mtspr	SPRG2,r6
	mtspr	SPRG3,r7
	
	mfspr	r6,srr0
	mfspr	r7,srr1
	
	lwz	r4,0(r6)
	mfmsr	r4
	ori	r4,r4,(PSL_IR|PSL_DR)
	mtmsr	r4				#Reenable MMU (can affect srr0/srr1 acc Docs)
	isync
	
	lis	r3,EUMBEPICPROC
	lwz	r4,0xa0(r3)			#Read IACKR to acknowledge it
	eieio
	
	rlwinm	r4,r4,8,0,31
	cmpwi	r4,0x00ff			#Spurious Vector. Should not do EOI acc Docs.
	beq	NoEOI
	
	lis	r3,EUMB
	lis	r4,0x100			#Clear IM0 bit to clear interrupt
	stw	r4,0x100(r3)
	eieio
	
	clearreg r4
	lis	r3,EUMBEPICPROC
	sync
	stw	r4,0xb0(r3)			#Write 0 to EOI to End Interrupt
	
NoEOI:	
	lis	r3,0x200
	lwz	r4,0(r3)			#DEBUG Counter
	addi	r4,r4,1
	stw	r4,0(r3)
	lis	r3,0x7e00
	lwz	r4,0(r3)
	addi	r4,r4,1
	stw 	r4,4(r3)
	
	mtspr	srr0,r6
	mtspr	srr1,r7
	mfspr	r3,SPRG0
	mfspr	r4,SPRG1
	mfspr	r6,SPRG2
	mfspr	r7,SPRG3
	sync
	rfi
EIntEnd:


#********************************************************************************************

	.space 0x400 - (EIntEnd-EInt+8)		#0x900	Decrementer
Halt2:	ori	r0,r0,0         		#no-op
	b	Halt2
DecSt:	
	ori	r0,r0,0
	rfi
DecEnd:

#********************************************************************************************

	
	.space	0x2700 - (DecEnd-DecSt+8)	#0x3000 	End of Exception Vectors Table
Halt3:	ori	r0,r0,0         		#no-op
	b	Halt3
						#Start Exception Handler
ExHandler:					#Nothing for now
	blr	
ExHandlerEnd:
#********************************************************************************************	
	
	.space 0x1000 - (ExHandlerEnd-ExHandler)	#0x4000	System initialization
system_reset:
		
	lis	r22,CMD_BASE
	lis	r29,VEC_BASE
	ori	r29,r29,0x6000			#For initial communication

	bl	Reset
	
	setpcireg PICR1
	loadreg r25,VAL_PICR1
	bl	ConfigWrite32
	setpcireg PICR2
	loadreg r25,VAL_PICR2
	bl	ConfigWrite32
	setpcireg PMCR1
	loadreg r25,VAL_PMCR1
	bl	ConfigWrite16
	setpcireg EUMBBAR
	lis	r25,EUMB
	bl	ConfigWrite32
	
	bl	ConfigMem			#Result = Sonnet Mem Len in r8
	li	r3,0				#To RAM at 0x0
	lis	r4,0xfff0			#From "ROM"
	li	r5,0x4000			#Bytes copied + Offset
	li	r6,0x100			#Offset
	bl	copy_and_flush
	
	lis	r27,0x8000			#Upper boundary PCI Memory Mediator
	mr	r26,r8				#Oops, hardcoded

	li	r28,17
	mtctr	r28	
	li	r28,1
	li	r25,29
	
Loop1:	slw.	r26,r26,r28
	blt	Fndbit
	addi	r25,r25,-1
	bdnz	Loop1
	b	agentBoot
	
Fndbit:	slw.	r26,r26,r28
	beq	SetLen
	addi	r25,r25,1

SetLen:	mr	r30,r28
	slw	r30,r30,r25
	slw	r30,r30,r28
	subf	r27,r30,r27
	lis	r26,EUMB
	ori	r26,r26,ITWR	
	stwbrx	r25,0,r26			#debug = 0x19 (=48MB, Development system)
	sync

	setpcireg LMBAR
	mr	r25,r27
	ori	r25,r25,8			#debug = 0x7c000008
	bl	ConfigWrite32

	stw	r27,8(r29)			#MemStart
	stw	r8,12(r29)			#MemLen
	
	bl	mmuSetup
	bl	Epic
	bl	Caches

	mfspr	r3,PVR				#Get CPU Type
	li	r1,0
	stw	r3,12(r1)			#Store at SonnetBase+12	

	lis	r3,0x9				#Usercode hardcoded at 0x90000
						#This should become the idle task
	loadreg	r1,0x7fffc			#Userstack in unused mem (See BootPPC.s)
	lis	r15,0
	stw	r15,0(r1)
	li	r2,-8192			#SDA (0x6000-0x16000)
	loadreg	r13,0x1e000			#SDA2 (0x16000-0x26000)
	bl	End
	
Start:	li	r25,0
	lwz	r28,0(r25)
	stw	r28,4(r29)			#Code word		
agentBoot:
	ori	r0,r0,0
	ori	r0,r0,0
	ori	r0,r0,0         		#no-op
	ori	r0,r0,0         		#no-op
	b	agentBoot

End:	mflr	r4
	
	addi	r5,r4,End-Start
	subf	r5,r4,r5
	li	r6,0
	bl	copy_and_flush			#Put program in Sonnet Mem instead if PCI Mem
	

	mtdec	r3
	isync
	lis	r14,0
	mtspr	285,r14
	mtspr	284,r14				#Time Base Lower	

	
	mfmsr	r14
	ori	r14,r14,0x8000			#Enable External Exceptions
	mtmsr	r14
	isync
	
	mtspr	srr0,r3
	isync
	mtspr	srr1,r14
	isync
	sync	
	rfi					#To user code

#********************************************************************************************

						#Clear MSR to diable interrupts and checks
Reset:	mflr	r15
	mfmsr	r1
	andi.	r1,r1,0x40
	sync
	mtmsr	r1				#Clear MSR, keep Interrupt Prefix for now 
	isync
						#Zero-out registers  
	andi.   r0, r0, 0
	mtspr   SPRG0, r0
	mtspr   SPRG1, r0
	mtspr   SPRG2, r0
	mtspr   SPRG3, r0
						#Set HID0 to known state 
	lis	r3,HID0_NHR@h
	ori	r3,r3,HID0_NHR@l
	mfspr	r4,HID0
	and	r3,r4, r3			#Clear other bits 
	mtspr	HID0,r3
	sync

						#Set MPU/MSR to a known state. Turn on FP 
 	lis	r3,PPC_MSR_FP@h
	ori	r3,r3,PPC_MSR_FP@l
	or	r3,r1,r3
	sync
	mtmsr 	r3
	isync
						#Init the floating point control/status register 
 	mtfsfi  7,0
	mtfsfi  6,0
	mtfsfi  5,0
	mtfsfi  4,0
	mtfsfi  3,0
	mtfsfi  2,0
	mtfsfi  1,0
	mtfsfi  0,0
	isync
						#Initialize floating point data regs to known state 
	bl	ifpdr_value
.word	0x3f80,0x0000				#Value of 1.0
ifpdr_value:
	mflr	r3
	lfs	f0,0(r3)
	lfs	f1,0(r3)
	lfs	f2,0(r3)
	lfs	f3,0(r3)
	lfs	f4,0(r3)
	lfs	f5,0(r3)
	lfs	f6,0(r3)
	lfs	f7,0(r3)
	lfs	f8,0(r3)
	lfs	f9,0(r3)
	lfs	f10,0(r3)
	lfs	f11,0(r3)	
	lfs	f12,0(r3)
	lfs	f13,0(r3)
	lfs	f14,0(r3)
	lfs	f15,0(r3)
	lfs	f16,0(r3)
	lfs	f17,0(r3)
	lfs	f18,0(r3)
	lfs	f19,0(r3)
	lfs	f20,0(r3)
	lfs	f21,0(r3)	
	lfs	f22,0(r3)
	lfs	f23,0(r3)
	lfs	f24,0(r3)
	lfs	f25,0(r3)
	lfs	f26,0(r3)
	lfs	f27,0(r3)
	lfs	f28,0(r3)
	lfs	f29,0(r3)
	lfs	f30,0(r3)
	lfs	f31,0(r3)
	sync
						#Clear BAT and Segment mapping registers 
	andi.	r1,r1,0
	mtspr	ibat0u,r1
	mtspr	ibat1u,r1
	mtspr	ibat2u,r1
	mtspr	ibat3u,r1	
	mtspr	dbat0u,r1
	mtspr	dbat1u,r1
	mtspr	dbat2u,r1
	mtspr	dbat3u,r1
	
	isync
	sync
	sync
	lis	r1,0x8000
	isync
	mtsr	0,r1
	mtsr	1,r1
	mtsr	2,r1
	mtsr	3,r1
	mtsr	4,r1
	mtsr	5,r1
	mtsr	6,r1
	mtsr	7,r1
	mtsr	8,r1
	mtsr	9,r1
	mtsr	10,r1
	mtsr	11,r1
	mtsr	12,r1
	mtsr	13,r1
	mtsr	14,r1
	mtsr	15,r1
	isync
	sync
	sync
						#Turn off caches and invalidate them 

	mfl2cr	r3				
	rlwinm  r3,r3,0,1,31	  	   	#turn off the L2 enable bit 
	mtl2cr	r3				
	isync

	oris	r3,r3,L2CR_L2I@h
	mtl2cr	r3				
	sync
Wait1:
	mfl2cr	r3				
	andi.	r3,r3,L2CR_L2IP@l
	cmpwi	r3,L2CR_L2IP@l
	beq	Wait1				#Wait for invalidate done 

						#Invalidate L1 Cache 
	mfspr   r3,HID0
	isync
	rlwinm  r4,r3,0,18,15			#Clear d16 and d17 to disable L1 cache 
	sync
	isync
	mtspr   HID0,r4 			#turn off caches 
	isync

	lis	r3,0
	ori	r3,r3,HID0_ICFI@l		#Invalidates instruction caches 
	or	r4,r4,r3
	sync
	isync
	mtspr	HID0,r4
	andc	r4,r4,r3
	isync

	lis	r3,0
	ori	r3,r3,HID0_DCFI@l		#Invalidates data caches 
	or	r4,r4,r3
	sync
	isync
	mtspr	HID0,r4
	andc	r4,r4,r3
	isync

	li	r11,0x2000			#No harm 
	mtctr	r11
Delay1:
	bdnz	Delay1

	isync
	mfspr	r4,HID0
	isync
	ori	r4,r4,(HID0_ICE|HID0_ICFI)
	isync
	mtspr	HID0,r4				#turn on i-cache for speed 
	rlwinm	r4,r4,0,21,19			#clear the ICFI bit 
	isync
	mtspr	HID0,r4

	mtlr	r15
	blr

#********************************************************************************************


Epic:	lis	r26,EUMB
	loadreg	r27,EPIC_GCR
	add	r27,r26,r27
	li	r28,0xa0				
	stw	r28,0(r27)			#Reset EPIC
	
ResLoop:
	lwz	r28,0(r27)
	andi.	r28,r28,0x80
	bne	ResLoop				#Wait for reset

	li	r28,0x20
	stw	r28,0(r27)			#Set Mixed Mode
	
	loadreg	r28,0x80050042
	loadreg	r27,EPIC_IIVPR3
	add	r27,r26,r27
	stwbrx	r28,0,r27			#Set MU interrupt, Pri = 5, Vector = 0x42
	sync
	
	loadreg r28,0x10000			#Set Slice/Quantum
	loadreg r27,EPIC_GTBCR0
	add	r27,r26,r27
	stwbrx	r28,0,r27
	sync	
	loadreg r28,0x80040043
	loadreg r27,EPIC_GTVPR0
	add	r27,r26,r27
	stwbrx	r28,0,r27
	sync	
	
	loadreg	r27,EPIC_EICR
	add	r27,r26,r27
	lwz	r28,0(r27)
	rlwinm	r28,r28,0,21,19			#Doc says Set SIE = 0
	stw	r28,0(r27)	
	sync

	loadreg	r27,EPIC_IIVPR3
	add 	r27,r26,r27
	lwz	r28,0(r27)
	rlwinm	r28,r28,0,25,23			#Doc says Mask M bit now. Can maybe already at
	stw	r28,0(r27)			#while setting the interrupt above?
	sync
	
	loadreg	r27,EPIC_GTVPR0
	add 	r27,r26,r27
	lwz	r28,0(r27)
	rlwinm	r28,r28,0,25,23			#Doc says Mask M bit now. Can maybe already at
	stw	r28,0(r27)			#while setting the interrupt above?
	sync	
	
	loadreg	r27,EPIC_PCTPR
	add	r27,r26,r27
	lis	r28,0
	stw	r28,0(r27)			#Doc says Set Pri (Task) = 0
	
	loadreg	r27,EPIC_FRR
	add	r27,r26,r27
	
	lwbrx	r28,0,r27
	rlwinm	r28,r28,16,21,31		#Get FRR[NIRQ]

	mtctr	r28				#Doc says clear all possible ints
	lis	r26,EUMBEPICPROC

ClearInts:
	lwz	r27,0xa0(r26)			#IACKR
	eieio
	clearreg r27
	sync
	stw	r27,0xb0(r26)			#EOI
	bdnz	ClearInts
	
	blr
	
#********************************************************************************************	

						#Enable L1 data cache 
Caches:	mfspr	r4,HID0	
	ori	r4,r4,HID0_ICE|HID0_DCE|HID0_SGE|HID0_BTIC|HID0_BHTE@l
	isync
	mtspr	HID0,r4				#Enable D-cache
	isync
	
						# Set up on chip L2 cache controller.

	lis	r4,L2CR_L2SIZ_1M|L2CR_L2CLK_3|L2CR_L2RAM_BURST@h
	ori	r4,r4,0
	
	mtl2cr	r4				
	sync
	mfl2cr	r5				
	oris	r5,r5,L2CR_L2I@h
	mtl2cr	r5				
	sync
	
Wait2:
	mfl2cr	r3				
	andi.	r3,r3,L2CR_L2IP@l
	cmpwi	r3,L2CR_L2IP@l
	beq	Wait2				#Wait for invalidate done 

	oris	r4,r4,L2CR_L2E@h
	mtl2cr	r4				#Enable L2 cache 
	sync
	isync
	blr


#********************************************************************************************
	
mmuSetup:					#Could be simpler

	lis r4,IBAT0L_VAL@h
	ori r4,r4,IBAT0L_VAL@l
	lis r3,IBAT0U_VAL@h
	ori r3,r3,IBAT0U_VAL@l
	mtspr ibat0l,r4
	mtspr ibat0u,r3
	isync

	lis r4,DBAT0L_VAL@h
	ori r4,r4,DBAT0L_VAL@l
	lis r3,DBAT0U_VAL@h
	ori r3,r3,DBAT0U_VAL@l
	mtspr dbat0l,r4
	mtspr dbat0u,r3
	isync

	lis r4,IBAT1L_VAL@h
	ori r4,r4,IBAT1L_VAL@l
	lis r3,IBAT1U_VAL@h
	ori r3,r3,IBAT1U_VAL@l
	mtspr ibat1l,r4
	mtspr ibat1u,r3
	isync

	lis r4,DBAT1L_VAL@h
	ori r4,r4,DBAT1L_VAL@l
	lis r3,DBAT1U_VAL@h
	ori r3,r3,DBAT1U_VAL@l
	mtspr dbat1l,r4
	mtspr dbat1u,r3
	isync

	lis r4,IBAT2L_VAL@h
	ori r4,r4,IBAT2L_VAL@l
	lis r3,IBAT2U_VAL@h
	ori r3,r3,IBAT2U_VAL@l
	
	or r3,r3,r27
	
	mtspr ibat2l,r4
	mtspr ibat2u,r3
	isync

	lis r4,DBAT2L_VAL@h
	ori r4,r4,DBAT2L_VAL@l
	lis r3,DBAT2U_VAL@h
	ori r3,r3,DBAT2U_VAL@l
	
	or r3,r3,r27
	
	mtspr dbat2l,r4
	mtspr dbat2u,r3
	isync

	lis r4,IBAT3L_VAL@h
	ori r4,r4,IBAT3L_VAL@l
	lis r3,IBAT3U_VAL@h
	ori r3,r3,IBAT3U_VAL@l
	mtspr ibat3l,r4
	mtspr ibat3u,r3
	isync

	
	lis r4,DBAT3L_VAL@h
	ori r4,r4,DBAT3L_VAL@l
	lis r3,DBAT3U_VAL@h
	ori r3,r3,DBAT3U_VAL@l
	mtspr dbat3l,r4
	mtspr dbat3u,r3
	isync
						#BATs are now set up, now invalidate tlb entries
	lis r3,0	
	lis r5,0x4				#750/MAX have 2x as many tlbs as 603e (Would be 0x2)
	isync

#Recall that in order to invalidate TLB entries, the value issued to
#tlbie must increase the value in bits 14:19 (750, MAX) or 15:19(603e)
#by one each iteration.


tlblp:
	tlbie r3
	sync
	addi r3,r3,0x1000
	cmp 0,0,r3,r5				#check if all TLBs invalidated yet
	blt tlblp
	
	mfmsr	r4
	ori	r4,r4,0x00000030			#Translation enable 
	andi.	r4,r4,0xffbf			#Exception prefix from 0xfff00000 to 0x0
	mtmsr	r4
	isync

	blr
#********************************************************************************************		
	
ConfigWrite32:
	lis	r20,CONFIG_ADDR
	lis 	r21,CONFIG_DAT
	stwbrx	r23,0,r20
	sync
	stwbrx	r25,0,r21
	sync
	blr

ConfigWrite16:
	lis	r20,CONFIG_ADDR
	lis 	r21,CONFIG_DAT
	stwbrx	r23,0,r20
	sync
	sthbrx	r25,0,r21
	sync
	blr
		
ConfigWrite8:
	lis	r20,CONFIG_ADDR
	stwbrx	r23,0,r20
	sync
	andi.	r19,r23,3
	oris	r21,r19,CONFIG_DAT
	stb	r25,0(r21)
	sync
	blr

#********************************************************************************************
	
ConfigMem:					#Code lifted from the Sonnet Driver
	mflr	r15				#by Mastatabs from A1k fame

	setpcireg MCCR4		
	lis	r25,0x0010	
	mr	r25,r25			#nop ?
	bl	ConfigWrite32		#set MCCR4 to 0x100000 BUFTYPE[1] = 

	setpcireg MCCR3	
	lis	r25,0x2
	ori	r25,r25,0xa29c		#0x2A29C  0101 010 001 010 011 100,
					#RP1  RAS Precharge = 4 3b100
					#(4 clocks are 110 per pdf, seems docu is wrong)
					#RCD2 RAS to CAS delay = 3
					#CAS3 CAS assertion = 2
					#CP4  CAS precharge = 1
					#CAS5 CAS assertion = 2																	
					#CBR  RAS assertion = 5
					#CAS write timing modifier DRAM = 0	
					#31-19 = 0
	bl	ConfigWrite32		#set MCCR3 to 0x2A29C
	
	setpcireg MCCR2	
	lis	r25,0xe000
	ori	r25,r25,0x1040
	bl	ConfigWrite32		#set MCCR2 to 0xE0001040
					#MCCR2 Memory Control Config Reg   = 0xe0001040
					#    Read Modify Write parity      = 0x0 Disabled
					#    RSV_PG Reserve one open page  = 0x0 Four open page mode
					#    Refresh Interval              = 0x0208 = 520 decimal
					#    EDO Enable                    = 0x0 standard DRAM
					#    ECC enable                    = 0x0 Disabled
					#    Inline Read Parity enable     = 0x0 Disabled
					#    Inline Report Parity enable   = 0x0 Disabled
					#    Inline Parity not ECC         = 0x0 Disabled
					#    ASFALL timing                 = 0x0 clocks
					#    ASRISE timing for Port X      = 0x0 clocks
					#    TS Wait Timer                 = 0x7 8 clocks min disable time

	setpcireg MCCR1
	lis	r25,0xffe2
	mr	r25,r25
	bl	ConfigWrite32		#Set MCCR1 to FFE20000	RAM_TYPE = 1 -> DRAM/EDO, 
					#SREN = 0 disable selfref, MEMGO = 0, 
					#BURST = 0, all banks 9 row bits

	setpcireg MSAR1
	clearreg r25
	bl	ConfigWrite32		#clear MSAR1

	setpcireg MESAR1
	clearreg r25
	bl	ConfigWrite32		#clear EMASR1

	setpcireg MSAR2
	clearreg r25
	bl	ConfigWrite32		#clear MASR2

	setpcireg MESAR2
	clearreg r25
	bl	ConfigWrite32		#clear EMASR2

	setpcireg MEAR1
	loadreg r25,0x7F7F7F7F
	bl	ConfigWrite32		#set MEAR1 to 7f7f7f7f

	setpcireg MEEAR1
	clearreg r25
	bl	ConfigWrite32		#clear EMEAR1

	setpcireg MEAR2
	loadreg r25,0x7F7F7F7F
	bl	ConfigWrite32		#set MEAR2 to 7f7f7f7f

	setpcireg MEEAR2
	clearreg r25
	bl	ConfigWrite32		#clear EMEAR2

	setpcireg MCCR1
	lis	r25,0xffea
	mr	r25,r25
	bl	ConfigWrite32		#set MCCR1 to ffea0000  set MEMGO!

	li	r3,0
	loadreg r4,"Boon"		#0x426F6F6E -> "Boon"
	li	r5,1
	li	r8,0
	li	r9,0
	li	r10,0
	li	r11,0
	li	r12,0
	lis	r13,0xffea		#ffea0000
	li	r14,0
	li	r16,0
	li	r17,0
	li	r18,0
	li	r19,0

loc_3BD8:
	setpcireg MBEN			#Memory Bank Enable Register
	mr	r25, r5
	bl	ConfigWrite8		#enable Bank 0

	stw	r4, 0(r3)		#try to store "Boon" at address 0x0
	eieio
	
	stw	r3, 4(r3)		#try to store 0x0 at 0x4
	eieio
	lwz	r7, 0(r3)		#read from 0x0
	cmplw	r4, r7			#is it "Boon", long compare
	bne	loc_4184
	
	or	r14, r14, r5		#continue if found
	
	setpcireg MCCR1			#0x800000f0
	loadreg r25,0xffeaffff		#-22,65535
	bl	ConfigWrite32		#set all banks to 12 or 13 row bits

	lis	r6, 0x40
	stw	r3, 0(r6)		#set 0x400000 to 0x0
	lis	r6, 0x80
	stw	r3, 0(r6)		#set 0x800000 to 0x0
	lis	r6, 0x100
	stw	r3, 0(r6)		#set 0x1000000 to 0x0
	lis	r6, 0x200
	stw	r3, 0(r6)		#set 0x2000000 to 0x0
	lis	r6, 0x400
	stw	r3, 0(r6)		#set 0x4000000 to 0x0
	lis	r6, 0x800
	stw	r3, 0(r6)		#set 0x8000000 to 0x0
	eieio
	stw	r4, 0(r3)		#set 0x0 to "Boon"
	eieio
	lis	r6, 0x40
	lwz	r7, 0(r6)		#read from 0x400000
	cmplw	r4, r7			#is it "Boon"
	beq	loc_3CBC		#if yes goto loc_3CBC
	lis	r6, 0x80
	lwz	r7, 0(r6)		#read form 0x800000
	cmplw	r4, r7			#is it "Boon"
	beq	loc_3E24		#if yes goto loc_3E24
	lis	r6, 0x100
	lwz	r7, 0(r6)		#read from 0x1000000
	cmplw	r4, r7			#is it "Boon"
	beq	loc_3E24		#if yes goto loc_3E24
	lis	r6, 0x200
	lwz	r7, 0(r6)		#read from 0x2000000
	cmplw	r4, r7
	beq	loc_3E24		#if its "Boon" goto loc_3E24
	lis	r6, 0x400
	lwz	r7, 0(r6)		#read from 0x4000000
	cmplw	r4, r7
	beq	loc_3E24		#if its "Boon" goto loc_3E24
	lis	r6, 0x800
	lwz	r7, 0(r6)		#read from 0x8000000
	cmplw	r4, r7
	beq	loc_3E24		#if its "Boon" goto loc_3E24
	b	loc_4184		#goto loc_4184

#********************************************************************************************
loc_3CBC:				#CODE XREF: findSetMem+1D0
	loadreg r25,0xFFEAAAAA		#set row bits to 11 row bits
	bl	ConfigWrite32
	lis	r6, 0x20			#continue tests
	stw	r3, 0(r6)
	lis	r6, 0x40
	stw	r3, 0(r6)
	lis	r6, 0x80
	stw	r3, 0(r6)
	lis	r6, 0x100
	stw	r3, 0(r6)
	lis	r6, 0x200
	stw	r3, 0(r6)
	eieio
	stw	r4, 0(r3)
	eieio
	lis	r6, 0x20
	lwz	r7, 0(r6)
	cmplw	r4, r7
	beq	loc_3D50
	lis	r6, 0x40
	lwz	r7, 0(r6)
	cmplw	r4, r7
	beq	loc_3E24
	lis	r6, 0x80
	lwz	r7, 0(r6)
	cmplw	r4, r7
	beq	loc_3E24
	lis	r6, 0x100
	lwz	r7, 0(r6)
	cmplw	r4, r7
	beq	loc_3E24
	lis	r6, 0x200
	lwz	r7, 0(r6)
	cmplw	r4, r7
	beq	loc_3E24
	b	loc_4184

#********************************************************************************************
loc_3D50:				#CODE XREF: findSetMem+274
	loadreg r25,0xFFEA5555		#set row bits to 10 row bits
	bl	ConfigWrite32
	lis	r6, 0x10			#continue tests
	stw	r3, 0(r6)
	lis	r6, 0x20
	stw	r3, 0(r6)
	lis	r6, 0x40
	stw	r3, 0(r6)
	lis	r6, 0x80
	stw	r3, 0(r6)
	eieio
	stw	r4, 0(r3)
	eieio
	lis	r6, 0x10
	lwz	r7, 0(r6)
	cmplw	r4, r7
	beq	loc_3DCC
	lis	r6, 0x20
	lwz	r7, 0(r6)
	cmplw	r4, r7
	beq	loc_3E24
	lis	r6, 0x40
	lwz	r7, 0(r6)
	cmplw	r4, r7
	beq	loc_3E24
	lis	r6, 0x80
	lwz	r7, 0(r6)
	cmplw	r4, r7
	beq	loc_3E24
	b	loc_4184

#********************************************************************************************
loc_3DCC:				#CODE XREF: findSetMem+300
	lis	r6, 8
	stw	r3, 0(r6)
	lis	r6, 0x10
	stw	r3, 0(r6)
	lis	r6, 0x20
	stw	r3, 0(r6)
	eieio
	stw	r4, 0(r3)
	eieio
	lis	r6, 8
	lwz	r7, 0(r6)
	cmplw	r4, r7
	beq	loc_4184
	lis	r6, 0x10
	lwz	r7, 0(r6)
	cmplw	r4, r7
	beq	loc_3E24
	lis	r6, 0x20
	lwz	r7, 0(r6)
	cmplw	r4, r7
	beq	loc_3E24
	b	loc_4184

#********************************************************************************************
loc_3E24:				#CODE XREF: findSetMem+1E0
					#findSetMem+1F0 ...
	cmplwi	r5, 1
	bne	loc_3E84
	mr	r7, r8
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	or	r9, r9, r7
	mr	r7, r8
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	or	r16, r16, r7
	add	r8, r8, r6
	mr	r7, r8
	addi	r7, r7, 0xFF
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	or	r11, r11, r7
	mr	r7, r8
	addi	r7, r7, 0xFF
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	or	r18, r18, r7
	andi.	r2, r2, 3
	or	r13, r13, r2
	b	loc_4184

#********************************************************************************************
loc_3E84:				#CODE XREF: findSetMem+394
	cmplwi	r5, 2
	bne	loc_3EF4
	mr	r7, r8
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	slwi	r7, r7, 8
	or	r9, r9, r7
	mr	r7, r8
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	slwi	r7, r7, 8
	or	r16, r16, r7
	add	r8, r8, r6
	mr	r7, r8
	addi	r7, r7, -1
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	slwi	r7, r7, 8
	or	r11, r11, r7
	mr	r7, r8
	addi	r7, r7, -1
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	slwi	r7, r7, 8
	or	r18, r18, r7
	andi.	r2, r2, 0xC
	or	r13, r13, r2
	b	loc_4184

#********************************************************************************************
loc_3EF4:				#CODE XREF: findSetMem+3F4
	cmplwi	r5, 4
	bne	loc_3F64
	mr	r7, r8
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	slwi	r7, r7, 16
	or	r9, r9, r7
	mr	r7, r8
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	slwi	r7, r7, 16
	or	r16, r16, r7
	add	r8, r8, r6
	mr	r7, r8
	addi	r7, r7, -1
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	slwi	r7, r7, 16
	or	r11, r11, r7
	mr	r7, r8
	addi	r7, r7, -1
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	slwi	r7, r7, 16
	or	r18, r18, r7
	andi.	r2, r2, 0x30
	or	r13, r13, r2
	b	loc_4184

#********************************************************************************************
loc_3F64:				#CODE XREF: findSetMem+464
	cmplwi	r5, 8
	bne	loc_3FD4
	mr	r7, r8
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	slwi	r7, r7, 24
	or	r9, r9, r7
	mr	r7, r8
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	slwi	r7, r7, 24
	or	r16, r16, r7
	add	r8, r8, r6
	mr	r7, r8
	addi	r7, r7, -1
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	slwi	r7, r7, 24
	or	r11, r11, r7
	mr	r7, r8
	addi	r7, r7, -1
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	slwi	r7, r7, 24
	or	r18, r18, r7
	andi.	r2, r2, 0xC0
	or	r13, r13, r2
	b	loc_4184

#********************************************************************************************
loc_3FD4:				#CODE XREF: findSetMem+4D4
	cmplwi	r5, 0x10
	bne	loc_4034
	mr	r7, r8
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	or	r10, r10, r7
	mr	r7, r8
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	or	r17, r17, r7
	add	r8, r8, r6

loc_4000:
	mr	r7, r8
	addi	r7, r7, -1
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	or	r12, r12, r7
	mr	r7, r8
	addi	r7, r7, -1
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	or	r19, r19, r7
	andi.	r2, r2, 0x300
	or	r13, r13, r2
	b	loc_4184

#********************************************************************************************
loc_4034:
	cmplwi	r5, 0x20

	bne	loc_40A4
	mr	r7, r8
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	slwi	r7, r7, 8
	or	r10, r10, r7
	mr	r7, r8
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	slwi	r7, r7, 8
	or	r17, r17, r7
	add	r8, r8, r6
	mr	r7, r8
	addi	r7, r7, -1
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	slwi	r7, r7, 8
	or	r12, r12, r7
	mr	r7, r8
	addi	r7, r7, -1
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	slwi	r7, r7, 8
	or	r19, r19, r7
	andi.	r2, r2, 0xC00
	or	r13, r13, r2
	b	loc_4184

#********************************************************************************************
loc_40A4:
	cmplwi	r5, 0x40
	bne	loc_4114
	mr	r7, r8
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	slwi	r7, r7, 16
	or	r10, r10, r7
	mr	r7, r8
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	slwi	r7, r7, 16
	or	r17, r17, r7
	add	r8, r8, r6
	mr	r7, r8
	addi	r7, r7, -1
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	slwi	r7, r7, 16
	or	r12, r12, r7
	mr	r7, r8
	addi	r7, r7, -1
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	slwi	r7, r7, 16
	or	r19, r19, r7
	andi.	r2, r2, 0x3000
	or	r13, r13, r2
	b	loc_4184

#********************************************************************************************
loc_4114:
	cmplwi	r5, 0x80
	bne	loc_4184
	mr	r7, r8
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	slwi	r7, r7, 24
	or	r10, r10, r7
	mr	r7, r8
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	slwi	r7, r7, 24
	or	r17, r17, r7
	add	r8, r8, r6
	mr	r7, r8
	addi	r7, r7, -1
	srwi	r7, r7, 20
	andi.	r7, r7, 0xFF
	slwi	r7, r7, 24
	or	r12, r12, r7
	mr	r7, r8
	addi	r7, r7, -1
	srwi	r7, r7, 28
	andi.	r7, r7, 3
	slwi	r7, r7, 24
	or	r19, r19, r7
	andi.	r2, r2, 0xc000
	or	r13, r13, r2
	b	loc_4184

loc_4184:
	slwi	r5, r5, 1
	cmplwi	r5, 0x100
	bne	loc_3BD8

	setpcireg MSAR1			#80
	mr	r25, r9
	bl	ConfigWrite32		#store found values to registers

	setpcireg MSAR2			#84
	mr	r25, r10
	bl	ConfigWrite32

	setpcireg MEAR1			#90
	mr	r25, r11
	bl	ConfigWrite32

	setpcireg MEAR2			#94
	mr	r25, r12
	bl	ConfigWrite32

	setpcireg MCCR1			#F0
	mr	r25, r13
	bl	ConfigWrite32

	setpcireg MBEN			#A0
	mr	r25, r14
	bl	ConfigWrite8

	setpcireg MESAR1		#88
	mr	r25, r16
	bl	ConfigWrite32

	setpcireg MESAR2		#8c
	mr	r25, r17
	bl	ConfigWrite32

	setpcireg MEEAR1		#98
	mr	r25, r18
	bl	ConfigWrite32

	setpcireg MEEAR2		#9C
	mr	r25, r19
	bl	ConfigWrite32

	addi	r16, r7, 4
	
	mtlr	r15
	blr
	
#********************************************************************************************
#Copy routine used to copy the kernel to start at physical address 0
#and flush and invalidate the caches as needed.
#r3 = dest addr, r4 = source addr, r5 = copy limit, r6 = start offset
#on exit, r3, r4, r5 are unchanged, r6 is updated to be >= r5.

copy_and_flush:
	addi	r5,r5,-4
	addi	r6,r6,-4
cachel:	li	r0,L1_CACHE_LINE_SIZE/4
	mtctr	r0
cachel1:	addi	r6,r6,4			#copy a cache line 
	lwzx	r0,r6,r4
	stwx	r0,r6,r3
	bdnz	cachel1
	dcbst	r6,r3				#write it to memory
	sync
	icbi	r6,r3				#flush the icache line
	cmplw	0,r6,r5
	blt	cachel
	sync					#additional sync needed on g4
	isync
	addi	r5,r5,4
	addi	r6,r6,4
	blr
#********************************************************************************************
PPCEnd:
