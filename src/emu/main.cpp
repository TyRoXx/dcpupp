#include <vector>
#include <string>
#include <iostream>
#include <fstream>
#include <cassert>
#include "machine.hpp"
#ifdef WIN32
#include <Windows.h>
#include <conio.h>
#endif
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
	unsigned updateInterval;
	
	Options()
		: sleepMs(10)
		, videoAddress(32768) //0x8000
		, updateInterval(5)
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

			case 'u':
				options.updateInterval = stoi(arg.c_str() + 2);
			
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
		unsigned intervalCounter;
#ifdef WIN32
		HANDLE console;
#endif
		
		explicit DebuggingContext(Machine &machine, const Options &options)
			: machine(machine)
			, options(options)
			, intervalCounter(0)
#ifdef WIN32
			, console(GetStdHandle(STD_OUTPUT_HANDLE))
#endif
		{
		}

		void printInfo()
		{
#ifdef WIN32
			{
				COORD coord = {0, 0};
				DWORD count;
				CONSOLE_SCREEN_BUFFER_INFO csbi;
				GetConsoleScreenBufferInfo(console, &csbi);
				FillConsoleOutputCharacter(console, ' ',
					csbi.dwSize.X * csbi.dwSize.Y,
					coord, &count);
				SetConsoleCursorPosition(console, coord);
			}
#else
			write(1, "\E[H\E[2J", 7);
#endif

#ifdef WIN32
			SetConsoleTextAttribute(console,
				FOREGROUND_BLUE | FOREGROUND_GREEN | FOREGROUND_RED | FOREGROUND_INTENSITY);
#endif
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
					const Word c = machine.memory[charAddress];

#ifdef WIN32
					SetConsoleTextAttribute(console, c >> 8);
#endif
					fputc((char)c, stdout);
					//write(1, &c, 1);
				}

				fputc('\n', stdout);
			}

			fflush(stdout);
			if (options.sleepMs)
			{
#ifdef WIN32
				Sleep(options.sleepMs);
#else
				usleep(options.sleepMs * 1000);
#endif
			}
		}
		
		bool startInstruction()
		{
			++intervalCounter;
			if (intervalCounter == options.updateInterval)
			{
				printInfo();
				intervalCounter = 0;
			}
			return true;
		}
	};
	
	DebuggingContext context(machine, options);
	machine.run(context);
}

