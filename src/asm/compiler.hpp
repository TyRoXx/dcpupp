#ifndef DCPUPP_ASM_COMPILER_HPP
#define DCPUPP_ASM_COMPILER_HPP


#include "parser.hpp"
#include <vector>


namespace dcpupp
{
	typedef std::vector<Word> MemoryBuffer;
	
	
	struct ICompilerErrorHandler
	{
		virtual ~ICompilerErrorHandler();
		virtual void handleError(const LexicalException &e) = 0;
		virtual void handleError(const SyntaxException &e) = 0;
		virtual void handleError(const SemanticException &e) = 0;
		virtual void handleRedefinition(
			SourceIterator previous,
			SourceIterator redefined,
			const std::string &name
			) = 0;
	};
	
	
	struct ILineHandler
	{
		virtual ~ILineHandler();
		virtual void handleLine(const Line &line) = 0;
	};
	
	
	struct Compiler
	{
		explicit Compiler(
			Parser &parser,
			MemoryBuffer &code,
			ICompilerErrorHandler &errorHandler
			);
		bool compile(ILineHandler *lineHandler = 0);
		
	private:
	
		Parser &m_parser;
		MemoryBuffer &m_code;
		ICompilerErrorHandler &m_errorHandler;
	};
}


#endif
