#ifndef DCPUPP_ASM_COMPILER_HPP
#define DCPUPP_ASM_COMPILER_HPP


#include "parser.hpp"
#include <vector>


namespace dcpupp
{
	typedef std::vector<std::uint16_t> MemoryBuffer;
	
	
	struct ICompilerErrorHandler
	{
		virtual ~ICompilerErrorHandler();
		virtual void handleError(const LexicalException &e) = 0;
		virtual void handleError(const SyntaxException &e) = 0;
		virtual void handleRedefinition(
			SourceIterator previous,
			SourceIterator redefined,
			const std::string &name
			) = 0;
	};
	
	
	struct Compiler
	{
		explicit Compiler(
			Parser &parser,
			MemoryBuffer &code,
			ICompilerErrorHandler &errorHandler
			);
		bool compile();
		
	private:
	
		Parser &m_parser;
		MemoryBuffer &m_code;
		ICompilerErrorHandler &m_errorHandler;
	};
}


#endif
