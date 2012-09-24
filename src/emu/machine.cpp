#include "machine.hpp"
#include <cassert>


namespace dcpupp
{
	Machine::Machine()
		: skipNext(false)
	{
		clearRegisters();
	}
	
	Machine::Machine(Memory memory)
		: memory(std::move(memory))
		, skipNext(false)
	{
		this->memory.resize(MemorySizeInWords);
		clearRegisters();
	}
	
	void Machine::clearRegisters()
	{
		sp = pc = o = 0;
		registers.fill(0);
	}
	
	Word &Machine::getArgument(unsigned argument, Word &sp_)
	{
		static std::array<Word, 32> SmallLiterals =
		{{
			0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
			0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
			0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
			0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
		}};
		
		switch (argument)
		{
		case 0x00: case 0x01: case 0x02: case 0x03:
		case 0x04: case 0x05: case 0x06: case 0x07:
			return registers[argument];
			
		case 0x08: case 0x09: case 0x0a: case 0x0b:
		case 0x0c: case 0x0d: case 0x0e: case 0x0f:
			return memory[registers[argument - 0x08]];
			
		case 0x10: case 0x11: case 0x12: case 0x13:
		case 0x14: case 0x15: case 0x16: case 0x17:
			return memory[memory[pc++] + registers[argument - 0x10]];
			
		case 0x18:
			return memory[sp_++];
			
		case 0x19:
			return memory[sp_];
			
		case 0x1a:
			return memory[--sp_];
			
		case 0x1b:
			return sp;
			
		case 0x1c:
			return pc;
			
		case 0x1d:
			return o;
			
		case 0x1e:
			return memory[memory[pc++]];
			
		case 0x1f:
			//not writeable
			return memory[pc++];
			
		default:
			//not writeable
			return SmallLiterals[argument - 32];
		}
	}
	
	
	Machine::Memory readProgramFromFile(
		std::istream &file
		)
	{
		Machine::Memory program(MemorySizeInWords);
		file.read(
			reinterpret_cast<char *>(program.data()),
			sizeof(program[0]) * program.size());
		return program;
	}
}

