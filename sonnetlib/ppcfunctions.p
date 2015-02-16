.include ppcdefines.i
.set MH_FIRST,16
.set MH_FREE,28
.set MC_BYTES,4
.set MC_NEXT,0
.set FunctionsLen,(EndFunctions-SetExcMMU)

.global FunctionsLen

.global SetExcMMU,ClearExcMMU,ConfirmInterrupt,InsertPPC,AddHeadPPC,AddTailPPC
.global RemovePPC,RemHeadPPC,RemTailPPC,EnqueuePPC,FindNamePPC,ResetPPC,NewListPPC
.global	AddTimePPC,SubTimePPC,CmpTimePPC,AllocVecPPC

.section "S_0","acrx"

#********************************************************************************************
#
#	void SetExcMMU(void) // Only from within Exception Handler
#
#********************************************************************************************

SetExcMMU:
		stw	r4,-8(r1)
		mfmsr	r4
		ori	r4,r4,(PSL_IR|PSL_DR)
		mtmsr	r4				#Reenable MMU
		isync
		lwz	r4,-8(r1)
		blr
	
#********************************************************************************************
#
#	void ClearExcMMU(void) // Only from within Exception Handler
#
#********************************************************************************************

ClearExcMMU:
		stw	r4,-8(r1)
		mfmsr	r4
		andi.	r4,r4,~(PSL_IR|PSL_DR)@l
		mtmsr	r4				#Disable MMU
		isync
		lwz	r4,-8(r1)
		blr	
	
#********************************************************************************************
#
#	void ConfirmInterrupt(void)
#
#********************************************************************************************

ConfirmInterrupt:
		stw	r3,-12(r1)
		stw	r4,-8(r1)
		lis	r3,EUMBEPICPROC
		lwz	r4,0xa0(r3)			#Read IACKR to acknowledge it
		eieio
	
		lis	r3,EUMB
		lis	r4,0x100			#Clear IM0 bit to clear interrupt
		stw	r4,0x100(r3)
		eieio

		clearreg r4
		lis	r3,EUMBEPICPROC
		sync
		stw	r4,0xb0(r3)			#Write 0 to EOI to End Interrupt

		lwz	r4,-8(r1)
		lwz	r3,-12(r1)
		blr

#********************************************************************************************
#
#	void InsertPPC(list, node, nodepredecessor) // r4,r5,r6 Node must be in Sonnet mem to work
#
#********************************************************************************************

InsertPPC:	
		mr.	r6,r6
		beq-	NoPred
		lwz	r3,0(r6)
		mr.	r3,r3
		beq-	Just1
		stw	r3,0(r5)
		stw	r6,4(r5)
		stw	r5,4(r3)
		stw	r5,0(r6)
		b	E1
Just1:		stw	r6,0(r5)
		lwz	r3,4(r6)
		stw	r3,4(r5)
		stw	r5,4(r6)
		stw	r5,0(r3)
		b	E1
NoPred:		lwz	r3,0(r4)			#Same as AddHeadPPC
		stw	r5,0(r4)
		stw	r3,0(r5)
		stw	r4,4(r5)
		stw	r5,4(r3)
E1:		blr	

#********************************************************************************************
#
#	void AddHeadPPC(list, node) // r4,r5 List/Node must be in Sonnet mem to work
#
#********************************************************************************************

AddHeadPPC:
		lwz	r3,0(r4)
		stw	r5,0(r4)
		stw	r3,0(r5)
		stw	r4,4(r5)
		stw	r5,4(r3)
		blr	

#********************************************************************************************
#
#	void AddTailPPC(list, node) // r4,r5 List/Node must be in Sonnet mem to work
#
#********************************************************************************************

AddTailPPC:
		addi	r4,r4,4
		lwz	r3,4(r4)
		stw	r5,4(r4)
		stw	r4,0(r5)
		stw	r3,4(r5)
		stw	r5,0(r3)
		blr	

#********************************************************************************************
#
#	void RemovePPC(node) // r4 Node must be in sonnet mem to work
#
#********************************************************************************************

RemovePPC:
		lwz	r3,0(r4)
		lwz	r4,4(r4)
		stw	r4,4(r3)
		stw	r3,0(r4)
		blr	


#********************************************************************************************
#
#	void RemHeadPPC(list) // r4 List must be in Sonnet mem to work
#
#********************************************************************************************

RemHeadPPC:
		lwz	r5,0(r4)
		lwz	r3,0(r5)
		mr.	r3,r3
		beq-	E2
		stw	r3,0(r4)
		stw	r4,4(r3)
		mr	r3,r5
E2:		blr	

#********************************************************************************************
#
#	void RemTailPPC(list) // r4 List must be in Sonnet mem to work (this msg won't be repeated from now on
#
#********************************************************************************************

RemTailPPC:
		lwz	r3,8(r4)
		lwz	r5,4(r3)
		mr.	r5,r5
		beq-	E3
		stw	r5,8(r4)
		addi	r4,r4,4
		stw	r4,0(r5)
E3:		blr	

#********************************************************************************************
#
#	void EnqueuePPC(list, node) // r4,r5
#
#********************************************************************************************

EnqueuePPC:
		lbz	r3,9(r5)
		extsb	r3,r3
		lwz	r6,0(r4)
Loop1:		mr	r4,r6
		lwz	r6,0(r4)
		mr.	r6,r6
		beq-	Link1
		lbz	r7,9(r4)
		extsb	r7,r7
		cmpw	r3,r7
		ble+	Loop1
		lwz	r3,4(r4)
Link1:		stw	r5,4(r4)
		stw	r4,0(r5)
		stw	r3,4(r5)
		stw	r5,0(r3)
		blr	

#********************************************************************************************
#
#	node = FindNamePPC(list, name) // r3=r4,r5
#
#********************************************************************************************


FindNamePPC:

		lwz	r3,0(r4)
		mr.	r3,r3
		beq-	E4
		subi	r8,r5,1
Loop2:		mr	r6,r3
		lwz	r3,0(r6)
		mr.	r3,r3
		beq-	E4
		lwz	r4,10(r6)
		mr	r5,r8
		subi	r4,r4,1
Loop3:		lbzu	r0,1(r4)
		lbzu	r7,1(r5)
		cmplw	r0,r7
		bne+	Loop2
		lbz	r0,0(r4)
		mr.	r0,r0
		bne+	Loop3
		mr	r3,r6
E4:		blr	

#********************************************************************************************
#
#	void ResetPPC(void)	// Dummy (as in powerpc.library
#
#********************************************************************************************

ResetPPC:
		blr
		

#********************************************************************************************
#
#	void NewListPPC(List)	// r4
#
#********************************************************************************************

NewListPPC:		
		stw	r4,8(r4)
		lis	r0,0
		nop	
		stwu	r0,4(r4)
		stw	r4,-4(r4)
		blr	

#********************************************************************************************
#
#	void AddTimePPC(Dest, Source)	// r4,r5
#
#********************************************************************************************

AddTimePPC:
		lwz	r6,4(r4)
		lwz	r7,4(r5)
		add	r6,r6,r7
		lis	r0,15
		ori	r0,r0,16960
		li	r3,0
		cmplw	r6,r0
		blt-	Link2
		sub	r6,r6,r0
		li	r3,1
Link2:		lwz	r8,0(r4)
		lwz	r9,0(r5)
		add	r8,r8,r9
		add	r8,r8,r3
		stw	r6,4(r4)
		stw	r8,0(r4)
		blr	

#********************************************************************************************
#
#	void SubTimePPC(Dest, Source)	// r4,r5
#
#********************************************************************************************

SubTimePPC:
		lwz	r6,4(r4)
		lwz	r7,4(r5)
		sub	r6,r6,r7
		li	r3,0
		mr.	r6,r6
		bge-	Link3
		lis	r0,15
		ori	r0,r0,16960
		add	r6,r6,r0
		li	r3,1
Link3:		lwz	r8,0(r4)
		lwz	r9,0(r5)
		sub	r8,r8,r9
		sub	r8,r8,r3
		stw	r6,4(r4)
		stw	r8,0(r4)
		blr	


#********************************************************************************************
#
#	Result = CmpTimePPC(Dest, Source)	// r3=r4,r5
#
#********************************************************************************************

CmpTimePPC:
		lwz	r6,0(r4)
		lwz	r7,0(r5)
		cmplw	r6,r7
		blt-	Link5
		bgt-	Link4
		lwz	r8,4(r4)
		lwz	r9,4(r5)
		cmplw	r8,r9
		blt-	Link5
		bgt-	Link4
		li	r3,0
		b	E5
Link4:		li	r3,-1
		b	E5
Link5:		li	r3,1
E5:		blr

#********************************************************************************************
#
#	MemBlock = AllocVecPPC(Length)	// r3=r4 (r5 and r6 are ignored) 4 byte alligned
#
#********************************************************************************************

AllocVecPPC:
		stwu	r31,-4(r1)
		stwu	r30,-4(r1)
		stwu	r29,-4(r1)
		stwu	r28,-4(r1)
		stwu	r23,-4(r1)
		stwu	r22,-4(r1)
		stwu	r21,-4(r1)
		stwu	r20,-4(r1)

		andi.	r3,r0,0
		addi	r29,r0,12
		addco.	r4,r4,r29
		loadreg r20,0xfffffffc
		and	r4,r4,r20
		li	r20,0
		lwz	r20,8(r20)
		lwz	r5,MH_FREE(r20)
		subfco	r31,r5,r4
		cmp	0,0,r5,r4
		bge	.R_AAAAAAAIC
		b	error
.R_AAAAAAAIC:
		lwz	r21,MH_FIRST(r20)
		addi	r23,r20,MH_FIRST
MemLoop:	lwz	r5,MC_BYTES(r21)
		subfco	r31,r5,r4
		cmp	0,0,r5,r4
		blt	.R_AAAAAAAIH
		b	FoundMem
.R_AAAAAAAIH:
		lwz	r30,MC_NEXT(r21)
		cmpi	0,0,r30,0
		bne	.R_AAAAAAAIJ
		b	error
.R_AAAAAAAIJ:
		mr	r23,r21
		lwz	r21,MC_NEXT(r21)
		b	MemLoop
		
FoundMem:	mr	r22,r21
		addco.	r22,r22,r4
		mr	r3,r21
		addi	r29,r0,8
		addco.	r3,r3,r29
		lwz	r29,MC_NEXT(r21)
		stw	r29,0(r22)
		lwz	r29,MC_BYTES(r21)
		stw	r29,4(r22)
		lwz	r30,MC_BYTES(r22)
		subfco	r28,r30,r4
		subf.	r30,r4,r30
		stw	r30,MC_BYTES(r22)
		lwz	r30,MH_FREE(r20)
		subfco	r28,r30,r4
		subf.	r30,r4,r30
		stw	r30,MH_FREE(r20)
		stw	r22,MC_NEXT(r23)
		rlwinm	r30,r3,0,24,31
		andi.	r30,r30,0xfc
		rlwimi	r3,r30,0,24,31
		stw	r4,MC_NEXT(r21)
		addi	r29,r0,5
		subfco	r28,r4,r29
		subf.	r4,r29,r4
		addi	r29,r0,4
		addco.	r21,r21,r29
ClrMem:		andi.	r30,r30,0
		stb	r30,0(r21)
		addi	r21,r21,1
		extsh	r29,r4
		cmpi	2,0,r29,0
		beq	cr2,.P_AAAAAAAJM
		subi	r29,r29,1
		rlwimi	r4,r29,0,16,31
		b	ClrMem
.P_AAAAAAAJM:
		subi	r29,r29,1
		rlwimi	r4,r29,0,16,31
error:		lwz	r20,0(r1)
		lwzu	r21,4(r1)
		lwzu	r22,4(r1)
		lwzu	r23,4(r1)
		lwzu	r28,4(r1)
		lwzu	r29,4(r1)
		lwzu	r30,4(r1)
		lwzu	r31,4(r1)
		addi	r1,r1,4
		blr
EndFunctions:		