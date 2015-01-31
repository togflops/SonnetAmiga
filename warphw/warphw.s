; IRA V2.08 (26.12.14) (c)1993-95 Tim Ruehsen, (c)2009-2014 Frank Wille

	
IMR0		EQU $50
LMBAR		EQU $10
PCSRBAR		EQU $14
	
	XREF	ConfirmInterrupt

;********************************************************************************************

	SECTION S_0,CODE

;********************************************************************************************


	MOVEQ	#-1,D0
	RTS
ROMTAG:
	DC.W	$4afc
	DC.L	ROMTAG
	DC.L	ENDSKIP
	DC.L	$80010900
	DC.L	WARPHWLIBNAME
	DC.L	IDSTRING
	DC.L	INIT
INIT:
	DC.L	$00000022
	DC.L	FUNCTABLE
	DC.L	DATATABLE
	DC.L	INITFUNCTION
DATATABLE:
	DC.L	$a0080900
	DC.W	$800a
	DC.L	WARPHWLIBNAME
	DC.L	$a00e0600,$90140001,$90160000
	DC.W	$8018
	DC.L	IDSTRING
	DS.L	1
ENDSKIP:
	DS.W	1
INITFUNCTION:
	MOVE.L	A6,-(A7)
	MOVE.L	A6,D1
	MOVEA.L	D0,A6
	MOVE.L	D1,SECSTRT_2
	MOVE.L	A0,LAB_0029
	CLR.L	LAB_002B
	MOVE.L	A6,-(A7)
	MOVE.L	A7,LAB_002C
	JSR	LAB_0015(PC)
	EXG	D0,D0
	TST.L	LAB_002B
	BNE.W	LAB_0006
	ADDQ.L	#4,A7
	MOVE.L	A6,D0
	MOVEA.L	(A7)+,A6
	RTS
LAB_0006:
	MOVEA.L	(A7),A6
	JSR	LAB_0019(PC)
	EXG	D0,D0
	MOVEQ	#0,D0
	MOVEA.L	A6,A1
	MOVE.W	16(A6),D0
	SUBA.L	D0,A1
	ADD.W	18(A6),D0
	MOVEA.L	SECSTRT_2,A6
	JSR	-210(A6)
	ADDQ.L	#4,A7
	MOVEQ	#0,D0
	MOVEA.L	(A7)+,A6
	RTS
OPEN:
	JSR	LAB_0009
	TST.L	D0
	BEQ.W	LAB_0008
	MOVEA.L	D0,A6
	ADDQ.W	#1,32(A6)
	BCLR	#3,LAB_002A
LAB_0008:
	RTS
LAB_0009:
	MOVE.L	A6,D0
	RTS
CLOSE:
	JSR	LAB_000C
	MOVEQ	#0,D0
	SUBQ.W	#1,32(A6)
	BNE.W	LAB_000B
	BTST	#3,LAB_002A
	BEQ.W	LAB_000B
	JSR	EXPUNGE
LAB_000B:
	RTS
LAB_000C:
	RTS
	DC.W	$4e71
EXPUNGE:
	MOVEM.L	D2,-(A7)
	TST.W	32(A6)
	BEQ.W	LAB_000E
	BSET	#3,LAB_002A
	MOVEQ	#0,D0
	BRA.W	LAB_000F
LAB_000E:
	MOVE.L	LAB_0029,D2
	MOVEA.L	A6,A1
	MOVE.L	A6,-(A7)
	MOVEA.L	SECSTRT_2,A6
	JSR	-252(A6)
	MOVEA.L	(A7)+,A6
	MOVE.L	A6,-(A7)
	JSR	LAB_0019(PC)
	EXG	D0,D0
	ADDQ.L	#4,A7
	MOVEQ	#0,D0
	MOVEA.L	A6,A1
	MOVE.W	16(A6),D0
	SUBA.L	D0,A1
	ADD.W	18(A6),D0
	MOVE.L	A6,-(A7)
	MOVEA.L	SECSTRT_2,A6
	JSR	-210(A6)
	MOVEA.L	(A7)+,A6
	MOVE.L	D2,D0
LAB_000F:
	MOVEM.L	(A7)+,D2
	RTS
	NOP
RESERVED:
	MOVEQ	#0,D0
	RTS
LAB_0011:
	MOVEQ	#0,D0
	BRA.S	LAB_0014
LAB_0012:
	MOVE.L	D0,D1
	ASL.L	#2,D1
	MOVEA.L	#LAB_002F,A1
	MOVE.L	0(A1,D1.L),D1
	CMPI.L	#$ffffffff,D1
	BNE.S	LAB_0013
	MOVE.L	D0,LAB_002E
	RTS
LAB_0013:
	ADDQ.L	#1,D0
LAB_0014:
	BRA.S	LAB_0012
	DS.W	1
LAB_0015:
	MOVEM.L	D2-D3/A6,-(A7)
	MOVEA.L	16(A7),A6
	JSR	LAB_0011
	MOVE.L	LAB_002E,D3
	CLR.L	LAB_002D
	MOVEQ	#0,D2
	BRA.S	LAB_0018
LAB_0016:
	MOVE.L	D2,D0
	ASL.L	#2,D0
	MOVEA.L	#LAB_002F,A1
	TST.L	0(A1,D0.L)
	BEQ.S	LAB_0017
	MOVE.L	D2,D0
	ASL.L	#2,D0
	MOVEA.L	#LAB_002F,A1
	MOVEA.L	0(A1,D0.L),A0
	JSR	(A0)
LAB_0017:
	ADDQ.L	#1,LAB_002D
	ADDQ.L	#1,D2
LAB_0018:
	CMP.L	D3,D2
	BLT.S	LAB_0016
	MOVEM.L	(A7)+,D2-D3/A6
	RTS
LAB_0019:
	MOVEM.L	D2/A6,-(A7)
	MOVEA.L	12(A7),A6
	MOVE.L	LAB_002E,D2
	SUB.L	LAB_002D,D2
	BRA.S	LAB_001C
LAB_001A:
	MOVE.L	D2,D0
	ASL.L	#2,D0
	MOVEA.L	#LAB_0030,A1
	TST.L	0(A1,D0.L)
	BEQ.S	LAB_001B
	MOVE.L	D2,D0
	ASL.L	#2,D0
	MOVEA.L	#LAB_0030,A1
	MOVEA.L	0(A1,D0.L),A0
	JSR	(A0)
LAB_001B:
	ADDQ.L	#1,D2
LAB_001C:
	CMP.L	LAB_002E,D2
	BLT.S	LAB_001A
	MOVEM.L	(A7)+,D2/A6
	RTS
	DS.L	2
	DC.W	$0003

GetDriverID:
	move.l #DriverID,d0
	rts

SupportedProtocol:
	moveq.l #1,d0
	rts

InitBootArea:
	movem.l d1-a6,-(a7)
	bsr.s FindSonnet
	addq.l #1,d1
	beq.s Error
	move.l LMBAR(a4),d0
	rol.w #8,d0
	swap d0
	rol.w #8,d0
	and.b #$f7,d0
	bra.s Error

BootPowerPC:
	rts
	
CauseInterrupt:
	movem.l d1-a6,-(a7)
	bsr.s FindSonnet
	addq.l #1,d1
	beq.s Error
	move.l PCSRBAR(a4),d0
	rol.w #8,d0
	swap d0
	rol.w #8,d0
	move.l d0,a0
	move.l #$deadc0de,IMR0(a0)
Error	nop	
	movem.l (a7)+,d1-a6
	rts

FindSonnet:
	moveq.l #0,d2
	moveq.l #$3f,d1				;Now follow some nasty absolute values
CpLoop	move.l #$40800000,a4
	move.l d2,d0
	lsl.l #3,d0
	lsl.l #8,d0
	add.l d0,a4
	move.l (a4),d4
	cmp.l #$FFFFFFFF,d4
	beq Error2
	cmp.l #$57100400,d4
	beq.s Sonnet
	addq.l #1,d2	
	dbf d1,CpLoop
Error2	move.l d4,d1	
Sonnet	rts


DriverID
	dc.b "WarpUp hardware driver for Sonnet Crescendo 7200 PCI",0
	cnop	0,2

	SECTION S_1,DATA

SECSTRT_2:
	DS.L	1
	DC.L	$000003ef
LAB_0029:
	DS.L	1
LAB_002A:
	DS.L	1
LAB_002B:
	DS.L	1
LAB_002C:
	DS.L	1
LAB_002D:
	DS.L	1
LAB_002E:
	DS.L	1
LAB_002F:
	DS.L	1
	DC.L	$ffffffff
LAB_0030:
	DS.L	1
	DC.L	$ffffffff
FUNCTABLE:
	DC.L	OPEN
	DC.L	CLOSE
	DC.L	EXPUNGE
	DC.L	RESERVED
	DC.L	GetDriverID
	DC.L	SupportedProtocol
	DC.L	InitBootArea
	DC.L	BootPowerPC
	DC.L	CauseInterrupt
	DC.L	ConfirmInterrupt
	DC.L	$ffffffff
WARPHWLIBNAME:
	DC.B	"warpHW.library",0,0
IDSTRING:
	DC.B	"$VER: warpHW.library 1.0 (31-Jan-15)",0
	cnop	0,2
	END