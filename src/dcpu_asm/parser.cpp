#include "parser.hpp"


namespace dcpupp
{
	Parser::Parser(
		Scanner &scanner,
		ILineHandler &lineHandler,
		IErrorHandler &errorHandler
		)
		: m_scanner(scanner)
		, m_lineHandler(lineHandler)
		, m_errorHandler(errorHandler)
	{
	}
	
	void Parser::parseLine()
	{
	}
}

