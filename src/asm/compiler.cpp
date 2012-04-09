#include "compiler.hpp"
#include <cassert>
#include <map>


namespace dcpupp
{
	ICompilerErrorHandler::~ICompilerErrorHandler()
	{
	}
	
	
	ILineHandler::~ILineHandler()
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
	
	bool Compiler::compile(ILineHandler *lineHandler)
	{
		struct Label
		{
			Word address;
			std::size_t line;
		};
		
		struct LabelManager : ILabelResolver
		{
			std::map<std::string, Label> labels;
			
			virtual bool resolve(const std::string &name, Word &value) const
			{
				auto pos = labels.find(name);
				if (pos == labels.end())
				{
					return false;
				}
				
				value = pos->second.address;
				return true;
			}
		}
		labelManager;
		
		bool success = true;
		std::vector<Line> lines;
		Word positionInMemory = 0;
		
		for (;;)
		{
			try
			{
				auto line = m_parser.parseLine();
				if (line.label.empty() && !line.statement)
				{
					break;
				}

				if (!line.label.empty())
				{
					const auto i = labelManager.labels.find(line.label);
					if (i == labelManager.labels.end())
					{
						Label label;
						label.address = positionInMemory;
						label.line = lines.size();

						labelManager.labels.insert(std::make_pair(
							line.label,
							label));
					}
					else
					{
						success = false;
						const Line &previousLine = lines[i->second.line];
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
			catch (const LexicalException &e)
			{
				success = false;
				m_errorHandler.handleError(e);
				m_parser.getScanner().skipLine();
				m_parser.resetCache();
			}
			catch (const SyntaxException &e)
			{
				success = false;
				m_errorHandler.handleError(e);
				m_parser.getScanner().skipLine();
				m_parser.resetCache();
			}
		}
		
		struct CodeWriter : IMemoryWriter
		{
			MemoryBuffer &buffer;
			
			explicit CodeWriter(MemoryBuffer &buffer)
				: buffer(buffer)
			{
			}
			
			virtual void write(Word value)
			{
				buffer.push_back(value);
			}

			virtual void reserve(Word size)
			{
				buffer.resize(buffer.size() + size);
			}
		};
		
		CodeWriter codeWriter(m_code);
		
		for (auto l = lines.begin(); l != lines.end(); ++l)
		{
			const Line &line = *l;
			
			if (lineHandler)
			{
				lineHandler->handleLine(line);
			}
			
			if (line.statement)
			{
				try
				{
					auto &statement = *line.statement;
					statement.compile(codeWriter, labelManager);
				}
				catch (const SemanticException &e)
				{
					m_errorHandler.handleError(e);
					success = false;
				}
			}
		}
		
		return success;
	}
}

