#ifndef DCPUPP_ASM_PARSER_HPP
#define DCPUPP_ASM_PARSER_HPP


#include "scanner.hpp"
#include <cstdint>
#include <memory>
#include <ostream>


namespace dcpupp
{
	enum SyntaxErrorCode
	{
		SynErr_LabelNameExpected,
		SynErr_MissingBracket,
		SynErr_KeywordExpected,
		SynErr_CommaExpected,
	};
	
	struct SyntaxException : Exception
	{
		SyntaxErrorCode error;
		
		explicit SyntaxException(
			SourceIterator position,
			SyntaxErrorCode error
			);
	};
	
	enum
	{
		UniversalRegisterCount = 8,
	};
	
	enum ArgumentType
	{
		Arg_Register,
		Arg_PtrRegister = 0x08,
		Arg_PtrRegisterWord = 0x10,
		Arg_Pop = 0x18,
		Arg_Peek = 0x19,
		Arg_Push = 0x1a,
		Arg_SP = 0x1b,
		Arg_PC = 0x1c,
		Arg_O = 0x1d,
		Arg_PtrWord = 0x1e,
		Arg_Word = 0x1f,
		Arg_SmallLiteral = 0x20,
	};
	
	struct Argument
	{
		virtual ~Argument();
		virtual void print(std::ostream &os) const = 0;
	};
	
	struct Register : Argument
	{
		unsigned id;
		
		explicit Register(unsigned id);
		virtual void print(std::ostream &os) const;
	};
	
	struct RegisterPtr : Argument
	{
		unsigned id;
		
		explicit RegisterPtr(unsigned id);
		virtual void print(std::ostream &os) const;
	};
	
	struct RegisterWordPtr : Argument
	{
		unsigned id;
		std::uint16_t next;
		
		explicit RegisterWordPtr(unsigned id, std::uint16_t next);
		virtual void print(std::ostream &os) const;
	};
	
	struct Pop : Argument
	{
		virtual void print(std::ostream &os) const;
	};
	
	struct Peek : Argument
	{
		virtual void print(std::ostream &os) const;
	};
	
	struct Push : Argument
	{
		virtual void print(std::ostream &os) const;
	};
	
	struct SP : Argument
	{
		virtual void print(std::ostream &os) const;
	};
	
	struct PC : Argument
	{
		virtual void print(std::ostream &os) const;
	};
	
	struct O : Argument
	{
		virtual void print(std::ostream &os) const;
	};
	
	struct WordPtr : Argument
	{
		std::uint16_t value;
		
		explicit WordPtr(std::uint16_t value);
		virtual void print(std::ostream &os) const;
	};
	
	struct Word : Argument
	{
		std::uint16_t value;
		
		explicit Word(std::uint16_t value);
		virtual void print(std::ostream &os) const;
	};
	
	struct SmallLiteral : Argument
	{
		unsigned value;
		
		explicit SmallLiteral(unsigned value);
		virtual void print(std::ostream &os) const;
	};
	
	struct Statement
	{
		virtual ~Statement();
		virtual void print(std::ostream &os) const = 0;
	};
	
	struct UnaryStatement : Statement
	{
		TokenId operation;
		std::unique_ptr<Argument> argument;
		
		explicit UnaryStatement(
			TokenId operation,
			std::unique_ptr<Argument> argument
			);
		virtual void print(std::ostream &os) const;
	};
	
	struct BinaryStatement : Statement
	{
		TokenId operation;
		std::unique_ptr<Argument> a, b;
		
		explicit BinaryStatement(
			TokenId operation,
			std::unique_ptr<Argument> a,
			std::unique_ptr<Argument> b
			);
		virtual void print(std::ostream &os) const;
	};
	
	struct Data : Statement
	{
		virtual void print(std::ostream &os) const;
	};
	
	struct Line
	{
		std::string label;
		std::unique_ptr<Statement> statement;
		
		explicit Line(
			std::string label,
			std::unique_ptr<Statement> statement);
		Line(Line &&other);
		Line &operator = (Line &&other);
		void swap(Line &other);
	};
	
	struct Parser
	{
		explicit Parser(
			Scanner &scanner
			);
		Line parseLine();
		
	private:
	
		Scanner &m_scanner;
		
		std::unique_ptr<Statement> parseBinaryStatement(TokenId operation);
		std::unique_ptr<Statement> parseUnaryStatement(TokenId operation);
		std::unique_ptr<Statement> parseData();
		std::unique_ptr<Argument> parseArgument();
	};
}


#endif
