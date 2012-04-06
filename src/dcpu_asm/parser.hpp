#ifndef DCPUPP_ASM_PARSER_HPP
#define DCPUPP_ASM_PARSER_HPP


#include "scanner.hpp"
#include <cstdint>


namespace dcpupp
{
	enum ArgumentType
	{
		Arg_Register,
		Arg_PtrRegister,
		Arg_PtrRegisterNext,
		Arg_Pop,
		Arg_Peek,
		Arg_Push,
		Arg_SP,
		Arg_PC,
		Arg_O,
		Arg_Literal,
	};
	
	struct Argument
	{
		ArgumentType type;
		std::uint16_t literal;
		std::uint16_t register_;
	};
	
	struct ILineHandler
	{
		virtual ~ILineHandler();
		virtual void handleLabel(const std::string &name) = 0;
		virtual void handleBinaryOperation(
			TokenId operation,
			const Argument &a,
			const Argument &b) = 0;
		virtual void handleUnaryOperation(
			TokenId operation,
			const Argument &argument) = 0;
	};
	
	enum SyntaxErrorCode
	{
		SynErr_MissingBracket,
	};
	
	struct IErrorHandler
	{
		virtual ~IErrorHandler();
		virtual void handleLexicalError(
			LexicalErrorCode error,
			SourceIterator position
			) = 0;
		virtual void handleSyntaxError(
			SyntaxErrorCode error,
			SourceIterator position
			) = 0;
	};
	
	struct Parser
	{
		explicit Parser(
			Scanner &scanner,
			ILineHandler &lineHandler,
			IErrorHandler &errorHandler
			);
		void parseLine();
		
	private:
	
		Scanner &m_scanner;
		ILineHandler &m_lineHandler;
		IErrorHandler &m_errorHandler;
	};
}


#endif
