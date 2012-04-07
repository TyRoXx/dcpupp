#include <vector>
#include <string>
#include <iostream>
#include <fstream>
#include <cassert>
using namespace std;

static void printHelp()
{
	cout << "" << endl;
}

struct Options
{
	unsigned videoAddress;
	
	Options()
		: videoAddress(32768) //0x8000
	{
	}
};

int main(int argc, char **argv)
{
	const vector<string> args(argv + 1, argv + argc);
	
	std::string source;
	std::string sourceFileName;
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
			sourceFileName = *a;
		}
	}
	
	if (sourceFileName.empty())
	{
		printHelp();
		return 0;
	}
	
	{
		std::ifstream sourceFile(sourceFileName.c_str(), std::ios::binary);
		if (!sourceFile)
		{
			cerr << "Could not open file '" << sourceFileName << "'" << endl;
			return 1;
		}
	
		source.assign(
			(std::istreambuf_iterator<char>(sourceFile)),
			std::istreambuf_iterator<char>());
	}
}
