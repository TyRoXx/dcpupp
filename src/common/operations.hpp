#ifndef DCPUPP_COMMON_OPERATIONS_HPP
#define DCPUPP_COMMON_OPERATIONS_HPP


namespace dcpupp
{
	enum OperationId
	{
		Op_NonBasic = 0x00,
		Op_Set = 0x01,
		Op_Add = 0x02,
		Op_Sub = 0x03,
		Op_Mul = 0x04,
		Op_Div = 0x05,
		Op_Mod = 0x06,
		Op_Shl = 0x07,
		Op_Shr = 0x08,
		Op_And = 0x09,
		Op_Bor = 0x0a,
		Op_Xor = 0x0b,
		Op_Ife = 0x0c,
		Op_Ifn = 0x0d,
		Op_Ifg = 0x0e,
		Op_Ifb = 0x0f,
	};

	enum NonBasicOperationId
	{
		NBOp_Jsr = 0x01,
	};
}


#endif
