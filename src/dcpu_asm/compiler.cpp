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
		struct LabelManager : ILabelResolver
		{
			std::map<std::string, std::uint16_t> labels;
			
			virtual bool resolve(const std::string &name, std::uint16_t &value) const
			{
				auto pos = labels.find(name);
				if (pos == labels.end())
				{
					return false;
				}
				
				value = pos->second;
				return true;
			}
		}
		labelManager;
		
		bool success = true;
		std::vector<Line> lines;
		std::uint16_t positionInMemory = 0;
		
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
				m_parser.getScanner().skipLine();
				continue;
			}
			catch (const SyntaxException &e)
			{
				success = false;
				m_errorHandler.handleError(e);
				m_parser.getScanner().skipLine();
				continue;
			}
			
			if (!line.label.empty())
			{
				const auto i = labelManager.labels.find(line.label);
				if (i == labelManager.labels.end())
				{
					labelManager.labels.insert(std::make_pair(
						line.label,
						positionInMemory));
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
			
			positionInMemory += line.getSizeInMemory();
			lines.push_back(std::move(line));
		}
		
		struct CodeWriter : IMemoryWriter
		{
			MemoryBuffer &buffer;
			
			explicit CodeWriter(MemoryBuffer &buffer)
				: buffer(buffer)
			{
			}
			
			virtual void write(std::uint16_t value)
			{
				buffer.push_back(value);
			}
		};
		
		CodeWriter codeWriter(m_code);
		
		for (auto line = lines.begin(); line != lines.end(); ++line)
		{
			if (line->statement)
			{
				auto &statement = *line->statement;
				statement.compile(codeWriter, labelManager);
			}
		}
		
		return success;
	}
}

