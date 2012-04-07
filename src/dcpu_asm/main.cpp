#include <vector>
#include <string>
#include <iostream>
#include <fstream>
#include <algorithm>
#include "compiler.hpp"
using namespace std;
using namespace dcpupp;


static void printHelp()
{
	cout << "" << endl;
}

struct ErrorHandler : ICompilerErrorHandler
{
	SourceIterator begin, end;
	
	explicit ErrorHandler(
		SourceIterator begin,
		SourceIterator end)
		: begin(begin)
		, end(end)
	{
	}
	
	virtual void handleError(const LexicalException &e)
	{
		cerr << "Lexical error (" << (getLine(e.position) + 1) << "): ";
		switch (e.error)
		{
		case LexErr_InvalidCharacter: cerr << "Invalid character '" << *e.position << "'"; break;
		case LexErr_IncompleteInteger: cerr << "Incomplete integer"; break;
		case LexErr_UnexpectedCharacter: cerr << "Unexpected character '" << *e.position << "'"; break;
		default: cerr << "Unknown error"; break;
		}
		cerr << endl;
	}
	
	virtual void handleError(const SyntaxException &e)
	{
		cerr << "Syntax error (" << (getLine(e.position) + 1) << "): ";
		switch (e.error)
		{
		case SynErr_LabelNameExpected: cerr << "Label name expected: " << getRestOfLine(e.position); break;
		case SynErr_MissingRightBracket: cerr << "Closing bracket ']' expected: " << getRestOfLine(e.position); break;
		case SynErr_KeywordExpected: cerr << "Keyword expected: " << getRestOfLine(e.position); break;
		case SynErr_CommaExpected: cerr << "Comma expected: " << getRestOfLine(e.position); break;
		case SynErr_ArgumentExpected: cerr << "Argument expected: " << getRestOfLine(e.position); break;
		case SynErr_DataExpected: cerr << "Data expected: " << getRestOfLine(e.position); break;
		case SynErr_UniversalRegisterExpected: cerr << "Universal register expected: " << getRestOfLine(e.position); break;
		default: cerr << "Unknown error"; break;
		}
		cerr << endl;
	}
	
	virtual void handleRedefinition(
		SourceIterator previous,
		SourceIterator redefined,
		const std::string &name
		)
	{
		cerr << "Redefinition (" << (getLine(redefined) + 1) << "): '" << name
			<< "' was defined in line " << (getLine(previous) + 1) << endl;
	}
	
private:

	unsigned getLine(SourceIterator position) const
	{
		return std::count(begin, position, '\n');
	}
	
	std::string getRestOfLine(SourceIterator position) const
	{
		return std::string(position,
			std::find(position, end, '\n'));
	}
};

int main(int argc, char **argv)
{
	const vector<string> args(argv + 1, argv + argc);
	
	if (args.empty())
	{
		printHelp();
		return 0;
	}
	
	const auto sourceFileName = args[0];
	
	std::string source;
	{
		std::ifstream file(sourceFileName.c_str(), std::ios::binary);
		if (!file)
		{
			cerr << "Could not open source file" << endl;
			return 1;
		}
	
		source.assign(
			(std::istreambuf_iterator<char>(file)),
			std::istreambuf_iterator<char>());
	}
	
	Scanner scanner(
		source.begin(),
		source.end());
	Parser parser(
		scanner);
	MemoryBuffer code;
	ErrorHandler errorHandler(
		source.begin(),
		source.end());
	Compiler compiler(
		parser,
		code,
		errorHandler);
	if (!compiler.compile())
	{
		return 1;
	}
	
	std::ofstream output((sourceFileName + ".bin").c_str(), std::ios::binary);
	if (!output)
	{
		cerr << "Could not open output file" << endl;
		return 1;
	}
	
	if (!code.empty())
	{
		output.write(
			reinterpret_cast<const char *>(&code[0]),
			sizeof(code[0]) * code.size());
	}
}

