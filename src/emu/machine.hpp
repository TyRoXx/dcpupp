#ifndef DCPUPP_EMU_MACHINE_HPP
#define DCPUPP_EMU_MACHINE_HPP


#include "common/operations.hpp"
#include "common/types.hpp"
#include <array>
#include <vector>
#include <istream>


namespace dcpupp
{
	
	enum
	{
		UniversalRegisterCount = 8,
		MemorySizeInWords = 0x10000,
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
			const bool isAWriteable = (a < 0x1f);
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
					case NBOp_Jsr: //JSR
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
					if (isAWriteable)
					{
						*a_ref = *b_ref;
					}
					break;
				}
				
			case Op_Add:
				{
					const auto result = *a_ref + *b_ref;
					o = (result > MaxWord);
					if (isAWriteable)
					{
						*a_ref = static_cast<Word>(result);
					}
					break;
				}
				
			case Op_Sub:
				{
					const auto result = *a_ref - *b_ref;
					o = (result > MaxWord) ? MaxWord : 0;
					if (isAWriteable)
					{
						*a_ref = static_cast<Word>(result);
					}
					break;
				}
				
			case Op_Mul:
				{
					const auto result = *a_ref * *b_ref;
					o = (result >> 16);
					if (isAWriteable)
					{
						*a_ref = static_cast<Word>(result);
					}
					break;
				}
				
			case Op_Div:
				{
					unsigned result;
					if (*b_ref == 0)
					{
						result = o = 0;
					}
					else
					{
						result = *a_ref / *b_ref;
						o = ((*a_ref << 16) / *b_ref);
					}
					if (isAWriteable)
					{
						*a_ref = static_cast<Word>(result);
					}
					break;
				}
				
			case Op_Mod:
				{
					if (isAWriteable)
					{
						if (*b_ref == 0)
						{
							*a_ref = 0;
						}
						else
						{
							*a_ref %= *b_ref;
						}
					}
					break;
				}
				
			case Op_Shl:
				{
					const auto result = *a_ref << *b_ref;
					o = (result >> 16);
					if (isAWriteable)
					{
						*a_ref = static_cast<Word>(result);
					}
					break;
				}
				
			case Op_Shr:
				{
					const auto result = *a_ref >> *b_ref;
					o = ((*a_ref << 16) >> *b_ref);
					if (isAWriteable)
					{
						*a_ref = static_cast<Word>(result);
					}
					break;
				}
				
			case Op_And:
				{
					if (isAWriteable)
					{
						*a_ref &= *b_ref;
					}
					break;
				}
				
			case Op_Bor:
				{
					if (isAWriteable)
					{
						*a_ref |= *b_ref;
					}
					break;
				}
				
			case Op_Xor:
				{
					if (isAWriteable)
					{
						*a_ref ^= *b_ref;
					}
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
