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
	};
	
	struct Machine
	{
		typedef std::array<Word, UniversalRegisterCount> Registers;
		typedef std::vector<Word> Memory;
		
		Registers registers;
		Word sp, pc, o;
		Memory memory;
		
		Machine();
		explicit Machine(Memory memory);
		void clearRegisters();
		
		template <class Context>
		void run(const Context &context);
	};

	template <class Context>
	void Machine::run(const Context &context)
	{
	}
	
	Machine::Memory readProgramFromFile(
		std::istream &file
		);
}


#endif
