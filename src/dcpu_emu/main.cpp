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
}

