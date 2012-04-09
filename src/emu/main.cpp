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
	unsigned consoleWidth;
	unsigned consoleHeight;
	
	Options()
		: sleepMs(10)
		, videoAddress(32768) //0x8000
		, updateInterval(5)
		, consoleWidth(32)
		, consoleHeight(12)
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
				break;

			case 'w':
				options.consoleWidth = stoi(arg.c_str() + 2);
				break;

			case 'h':
				options.consoleHeight = stoi(arg.c_str() + 2);
				break;
			
			default:
				cerr << "Invalid option '" << arg << "'";
				return 1;
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

		void setDefaultTextColors()
		{
#ifdef WIN32
			SetConsoleTextAttribute(console,
				FOREGROUND_BLUE | FOREGROUND_GREEN | FOREGROUND_RED | FOREGROUND_INTENSITY);
#endif
		}

		void printVerticalBar()
		{
			fputc(' ', stdout);
			for (size_t x = 0; x < options.consoleWidth; ++x)
			{
				fputc('-', stdout);
			}
			fputc('\n', stdout);
		}

		static char sanitizeCharacter(char c)
		{
			return (c >= 0 && c < ' ') ? ' ' : c;
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

			setDefaultTextColors();
			printf("A: %04x, B: %04x, C: %04x\n", machine.registers[0],
				machine.registers[1], machine.registers[2]);
			printf("X: %04x, Y: %04x, Z: %04x\n", machine.registers[3],
				machine.registers[4], machine.registers[5]);
			printf("I: %04x, J: %04x\n", machine.registers[6],
				machine.registers[7]);

			puts("");
			printf("SP: %04x, PC: %04x, O: %04x\n", machine.sp, machine.pc, machine.o);

			printVerticalBar();
			for (size_t y = 0; y < options.consoleHeight; ++y)
			{
				fputc('|', stdout);
				for (size_t x = 0; x < options.consoleWidth; ++x)
				{
					const size_t charAddress = options.videoAddress +
						y * options.consoleWidth +
						x;
					const Word c = machine.memory[charAddress];

#ifdef WIN32
					SetConsoleTextAttribute(console, c >> 8);
#endif
					fputc(sanitizeCharacter(static_cast<char>(c)), stdout);
				}
				setDefaultTextColors();
				fputc('|', stdout);
				fputc('\n', stdout);
			}
			printVerticalBar();
			fflush(stdout);
		}
		
		bool startInstruction()
		{
			++intervalCounter;
			if (intervalCounter == options.updateInterval)
			{
				printInfo();
				intervalCounter = 0;
			}

			if (options.sleepMs)
			{
#ifdef WIN32
				Sleep(options.sleepMs);
#else
				usleep(options.sleepMs * 1000);
#endif
			}
			return true;
		}
	};
	
	DebuggingContext context(machine, options);
	machine.run(context);
}

