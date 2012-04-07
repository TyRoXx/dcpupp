#include "machine.hpp"
#include <cassert>


namespace dcpupp
{
	Machine::Machine()
	{
		clearRegisters();
	}
	
	Machine::Machine(Memory memory)
		: memory(std::move(memory))
	{
		this->memory.resize(MemorySizeInWords);
		clearRegisters();
	}
	
	void Machine::clearRegisters()
	{
		sp = pc = o = 0;
		registers.fill(0);
	}
	
	
	Machine::Memory readProgramFromFile(
		std::istream &file
		)
	{
		Machine::Memory program(MemorySizeInWords);
		file.read(
			reinterpret_cast<char *>(program.data()),
			sizeof(program[0]) * program.size());
		return std::move(program);
	}
}

