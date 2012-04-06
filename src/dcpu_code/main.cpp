#include <vector>
#include <string>
#include <iostream>
using namespace std;


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
}

