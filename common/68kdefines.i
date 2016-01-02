
PPCMemHeader		EQU	8
TF_PPC			EQU	4
L1_CACHE_LINE_SIZE_040	EQU	16
COMMAND			EQU 	$4
Init			EQU	56
IMR0			EQU 	$50
IMR1			EQU	$54
OMISR			EQU 	$30
OMIMR			EQU 	$34
IFQPR			EQU	$40
OFQPR			EQU	$44
OMR0			EQU 	$58
OMR1			EQU 	$5C
LMBAR			EQU 	$10
PCSRBAR			EQU 	$14
OMBAR			EQU 	$300
OTWR			EQU 	$308
WP_CONTROL		EQU 	$F48
WP_TRIG01		EQU 	$c0000000
MEMF_PPC		EQU 	$2000
StackSize		EQU 	$10000
PageTableSize		EQU	$100000
TASKPPC_CTMEM		EQU 	256
TASKPPC_NAME		EQU	932
MN_ARG0			EQU	184
MN_ARG1			EQU	180
MN_ARG2			EQU	176
MN_MCTASK		EQU	188
_LVORawPutChar		EQU	-516	* Private function in Exec
VENDOR_ELBOX		EQU	$89e
VENDOR_ATI		EQU	$1002
VENDOR_3DFX		EQU	$121a
VENDOR_MOTOROLA		EQU	$1057
DEVICE_MPC107		EQU	$0004
DEVICE_VOODOO3		EQU	$0005
DEVICE_VOODOO4		EQU	$0007
DEVICE_VOODOO5		EQU	$0009
DEVICE_RV280PRO		EQU	$5960
DEVICE_RV280MOB		EQU	$5C63

FUNC_CNT	 EQU	-30		* Skip 4 standard vectors
FUNCDEF		 MACRO
_LVO\1		 EQU	FUNC_CNT
FUNC_CNT	 SET	FUNC_CNT-6	* Standard offset-6 bytes each
		 ENDM
