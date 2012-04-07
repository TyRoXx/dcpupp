#include "compiler.hpp"
#include <cassert>
#include <map>


namespace dcpupp
{
	ICompilerErrorHandler::~ICompilerErrorHandler()
	{
	}
	
	
	Compiler::Compiler(
		Parser &parser,
		MemoryBuffer &code,
		ICompilerErrorHandler &errorHandler
		)
		: m_parser(parser)
		, m_code(code)
		, m_errorHandler(errorHandler)
	{
	}
	
	bool Compiler::compile()
	{
		bool success = true;
		std::vector<Line> lines;
		std::map<std::string, std::size_t> labels;
		
		{
			for (;;)
			{
				Line line;
				try
				{
					if (!m_parser.parseLine(line))
					{
						break;
					}
				}
				catch (const LexicalException &e)
				{
					success = false;
					m_errorHandler.handleError(e);
					continue;
				}
				catch (const SyntaxException &e)
				{
					success = false;
					m_errorHandler.handleError(e);
					continue;
				}
				
				if (!line.label.empty())
				{
					const auto i = labels.find(line.label);
					if (i == labels.end())
					{
						labels.insert(std::make_pair(
							line.label,
							lines.size()));
					}
					else
					{
						success = false;
						const Line &previousLine = lines[i->second];
						m_errorHandler.handleRedefinition(
							previousLine.begin,
							line.begin,
							line.label
							);
					}
				}
				
				lines.push_back(std::move(line));
			}
		}
		
		return success;
	}
}

