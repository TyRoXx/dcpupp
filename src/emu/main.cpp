#include <vector>
#include <string>
#include <iostream>
#include <fstream>
#include "machine.hpp"
using namespace std;
using namespace dcpupp;

static void printHelp()
{
	cout << "" << endl;
}

int main(int argc, char **argv)
{
	const vector<string> args(argv + 1, argv + argc);
	
	if (args.empty())
	{
		printHelp();
		return 0;
	}
	
	Machine::Memory program;
	
	{
		const auto programFileName = args[0];
		std::ifstream programFile(programFileName.c_str(), std::ios::binary);
		if (!programFile)
		{
			cerr << "Could not open file" << endl;
			return 1;
		}
	
		program = readProgramFromFile(programFile);
	}
	
	Machine machine(std::move(program));
	
	struct DebuggingContext
	{
		Machine &machine;
		
		explicit DebuggingContext(Machine &machine)
			: machine(machine)
		{
		}
		
		bool startInstruction()
		{
#ifdef __unix__
			write(1, "\E[H\E[2J", 7);
			
			for (size_t i = 0; i < 8; ++i)
			{
				printf("%c: %04x, ", "ABCXYZIJ"[i], machine.registers[i]);
			}
			puts("");
			printf("SP: %04x, PC: %04x, O: %04x\n", machine.sp, machine.pc, machine.o);
			
			const size_t width = 32, height = 12;
			const size_t videoAddress = 0x8000;
			for (size_t y = 0; y < height; ++y)
			{
				for (size_t x = 0; x < width; ++x)
				{
					const size_t charAddress = videoAddress +
						y * width +
						x;
					const char c = (char)machine.memory[charAddress];
					fputc(c, stdout);
					//write(1, &c, 1);
				}
				
				fputc('\n', stdout);
			}
			
			fflush(stdout);
#endif
			return true;
		}
	};
	
	DebuggingContext context(machine);
	machine.run(context);
}

