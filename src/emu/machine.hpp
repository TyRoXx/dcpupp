#ifndef DCPUPP_EMU_MACHINE_HPP
#define DCPUPP_EMU_MACHINE_HPP


#include <array>
#include <vector>
#include <cstdint>
#include <istream>


namespace dcpupp
{
	typedef std::uint16_t Word;
	
	enum
	{
		UniversalRegisterCount = 8,
		MemorySizeInWords = 0x10000,
		MaxWord = 0xffff,
	};
	
	struct Machine
	{
		typedef std::array<Word, UniversalRegisterCount> Registers;
		typedef std::vector<Word> Memory;
		
		Registers registers;
		Word sp, pc, o;
		Memory memory;
		bool skipNext;
		
		Machine();
		explicit Machine(Memory memory);
		void clearRegisters();
		
		template <class Context>
		void run(Context &context);
		
		Word &getArgument(unsigned argument);
	};
	
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
	
	/*
    0x0: non-basic instruction - see below
    0x1: SET a, b - sets a to b
    0x2: ADD a, b - sets a to a+b, sets O to 0x0001 if there's an overflow, 0x0 otherwise
    0x3: SUB a, b - sets a to a-b, sets O to 0xffff if there's an underflow, 0x0 otherwise
    0x4: MUL a, b - sets a to a*b, sets O to ((a*b)>>16)&0xffff
    0x5: DIV a, b - sets a to a/b, sets O to ((a<<16)/b)&0xffff. if b==0, sets a and O to 0 instead.
    0x6: MOD a, b - sets a to a%b. if b==0, sets a to 0 instead.
    0x7: SHL a, b - sets a to a<<b, sets O to ((a<<b)>>16)&0xffff
    0x8: SHR a, b - sets a to a>>b, sets O to ((a<<16)>>b)&0xffff
    0x9: AND a, b - sets a to a&b
    0xa: BOR a, b - sets a to a|b
    0xb: XOR a, b - sets a to a^b
    0xc: IFE a, b - performs next instruction only if a==b
    0xd: IFN a, b - performs next instruction only if a!=b
    0xe: IFG a, b - performs next instruction only if a>b
    0xf: IFB a, b - performs next instruction only if (a&b)!=0
    */

	template <class Context>
	void Machine::run(Context &context)
	{
		next_instruction: while (context.startInstruction())
		{
			const auto instr = memory[pc];
			++pc;
			const auto a = (instr >> 4) & 0x3f;
			const auto op = (instr & 0x0f);
			Word *a_ref, *b_ref;
			
			if (op != Op_NonBasic)
			{
				a_ref = &getArgument(a);
				b_ref = &getArgument(instr >> 10);
				if (skipNext)
				{
					skipNext = false;
					goto next_instruction;
				}
			}
			
			switch (op)
			{
			case Op_NonBasic:
				{
					b_ref = &getArgument(instr >> 10);
					switch (a)
					{
					case 0x01: //JSR
						memory[--sp] = pc;
						pc = *b_ref;
						break;
						
					default:
						break;
					}
					break;
				}
				
			case Op_Set:
				{
					*a_ref = *b_ref;
					break;
				}
				
			case Op_Add:
				{
					const auto result = *a_ref + *b_ref;
					o = (result > MaxWord);
					*a_ref = static_cast<Word>(result);
					break;
				}
				
			case Op_Sub:
				{
					const auto result = *a_ref - *b_ref;
					o = (result > MaxWord) ? MaxWord : 0;
					*a_ref = static_cast<Word>(result);
					break;
				}
				
			case Op_Mul:
				{
					const auto result = *a_ref * *b_ref;
					o = (result >> 16);
					*a_ref = static_cast<Word>(result);
					break;
				}
				
			case Op_Div:
				{
					if (*b_ref == 0)
					{
						*a_ref = o = 0;
					}
					else
					{
						const auto result = *a_ref / *b_ref;
						o = ((*a_ref << 16) / *b_ref);
						*a_ref = static_cast<Word>(result);
					}
					break;
				}
				
			case Op_Mod:
				{
					if (*b_ref == 0)
					{
						*a_ref = 0;
					}
					else
					{
						*a_ref %= *b_ref;
					}
					break;
				}
				
			case Op_Shl:
				{
					const auto result = *a_ref << *b_ref;
					o = (result >> 16);
					*a_ref = static_cast<Word>(result);
					break;
				}
				
			case Op_Shr:
				{
					const auto result = *a_ref >> *b_ref;
					o = ((*a_ref << 16) >> *b_ref);
					*a_ref = static_cast<Word>(result);
					break;
				}
				
			case Op_And:
				{
					*a_ref &= *b_ref;
					break;
				}
				
			case Op_Bor:
				{
					*a_ref |= *b_ref;
					break;
				}
				
			case Op_Xor:
				{
					*a_ref ^= *b_ref;
					break;
				}
				
			case Op_Ife:
				{
					if (*a_ref != *b_ref)
					{
						skipNext = true;
					}
					break;
				}
				
			case Op_Ifn:
				{
					if (*a_ref == *b_ref)
					{
						skipNext = true;
					}
					break;
				}
				
			case Op_Ifg:
				{
					if (*a_ref <= *b_ref)
					{
						skipNext = true;
					}
					break;
				}
				
			case Op_Ifb:
				{
					if ((*a_ref & *b_ref) == 0)
					{
						skipNext = true;
					}
					break;
				}
			}
		}
	}
	
	Machine::Memory readProgramFromFile(
		std::istream &file
		);
}


#endif
