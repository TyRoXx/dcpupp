#include <vector>
#include <string>
#include <iostream>
#include <fstream>
#include <cassert>
#include "machine.hpp"
using namespace std;
using namespace dcpupp;

static void printHelp()
{
	cout << "" << endl;
}

struct Options
{
	unsigned sleepMs;
	unsigned videoAddress;
	
	Options()
		: sleepMs(10)
		, videoAddress(32768) //0x8000
	{
	}
};

int main(int argc, char **argv)
{
	const vector<string> args(argv + 1, argv + argc);
	
	Machine::Memory program;
	
	std::string programFileName;
	Options options;
	
	for (auto a = args.begin(); a != args.end(); ++a)
	{
		const auto &arg = *a;
		assert(!arg.empty());
		if (arg[0] == '-' &&
			arg.size() >= 2)
		{
			switch (arg[1])
			{
			case 's':
				options.sleepMs = atoi(arg.c_str() + 2);
				break;
			
			case 'v':
				options.videoAddress = atoi(arg.c_str() + 2);
				break;
			
			default:
				cerr << "Invalid option '" << arg << "'";
				break;
			}
		}
		else
		{
			programFileName = *a;
		}
	}
	
	if (programFileName.empty())
	{
		printHelp();
		return 0;
	}
	
	{
		std::ifstream programFile(programFileName.c_str(), std::ios::binary);
		if (!programFile)
		{
			cerr << "Could not open file '" << programFileName << "'" << endl;
			return 1;
		}
	
		program = readProgramFromFile(programFile);
	}
	
	Machine machine(std::move(program));
	
	struct DebuggingContext
	{
		Machine &machine;
		const Options &options;
		
		explicit DebuggingContext(Machine &machine, const Options &options)
			: machine(machine)
			, options(options)
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
			for (size_t y = 0; y < height; ++y)
			{
				for (size_t x = 0; x < width; ++x)
				{
					const size_t charAddress = options.videoAddress +
						y * width +
						x;
					const char c = (char)machine.memory[charAddress];
					fputc(c, stdout);
					//write(1, &c, 1);
				}
			
				fputc('\n', stdout);
			}
		
			fflush(stdout);
			if (options.sleepMs)
			{
				usleep(options.sleepMs * 1000);
			}
#endif
			return true;
		}
	};
	
	DebuggingContext context(machine, options);
	machine.run(context);
}

