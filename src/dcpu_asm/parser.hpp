#ifndef DCPUPP_ASM_PARSER_HPP
#define DCPUPP_ASM_PARSER_HPP


#include "scanner.hpp"
#include <cstdint>
#include <memory>
#include <ostream>
#include <vector>


namespace dcpupp
{
	enum SyntaxErrorCode
	{
		SynErr_LabelNameExpected,
		SynErr_MissingRightBracket,
		SynErr_KeywordExpected,
		SynErr_CommaExpected,
		SynErr_ArgumentExpected,
		SynErr_DataExpected,
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
	
	struct IMemoryWriter
	{
		virtual ~IMemoryWriter();
		virtual void write(std::uint16_t value) = 0;
	};
	
	struct ILabelResolver
	{
		virtual ~ILabelResolver();
		virtual bool resolve(const std::string &name, std::uint16_t &value) const = 0;
	};
	
	struct Argument
	{
		virtual ~Argument();
		virtual void print(std::ostream &os) const = 0;
		virtual std::uint16_t getExtraWordCount() const = 0;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			std::uint16_t &extra,
			ILabelResolver &resolver
			) const = 0;
	};
	
	struct Constant
	{
		virtual ~Constant();
		virtual std::uint16_t getValue(const ILabelResolver &resolver) const = 0;
		virtual void print(std::ostream &os) const = 0;
	};
	
	struct NumericConstant : Constant
	{
		std::uint16_t value;
		
		explicit NumericConstant(std::uint16_t value);
		virtual std::uint16_t getValue(const ILabelResolver &resolver) const;
		virtual void print(std::ostream &os) const;
	};
	
	struct LabelConstant : Constant
	{
		std::string name;
		
		explicit LabelConstant(std::string name);
		virtual std::uint16_t getValue(const ILabelResolver &resolver) const;
		virtual void print(std::ostream &os) const;
	};
	
	struct Register : Argument
	{
		unsigned id;
		
		explicit Register(unsigned id);
		virtual void print(std::ostream &os) const;
		virtual std::uint16_t getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			std::uint16_t &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct RegisterPtr : Argument
	{
		unsigned id;
		
		explicit RegisterPtr(unsigned id);
		virtual void print(std::ostream &os) const;
		virtual std::uint16_t getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			std::uint16_t &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct RegisterWordPtr : Argument
	{
		unsigned id;
		std::unique_ptr<Constant> extra;
		
		explicit RegisterWordPtr(
			unsigned id,
			std::unique_ptr<Constant> extra
			);
		virtual void print(std::ostream &os) const;
		virtual std::uint16_t getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			std::uint16_t &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct Pop : Argument
	{
		virtual void print(std::ostream &os) const;
		virtual std::uint16_t getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			std::uint16_t &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct Peek : Argument
	{
		virtual void print(std::ostream &os) const;
		virtual std::uint16_t getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			std::uint16_t &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct Push : Argument
	{
		virtual void print(std::ostream &os) const;
		virtual std::uint16_t getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			std::uint16_t &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct SP : Argument
	{
		virtual void print(std::ostream &os) const;
		virtual std::uint16_t getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			std::uint16_t &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct PC : Argument
	{
		virtual void print(std::ostream &os) const;
		virtual std::uint16_t getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			std::uint16_t &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct O : Argument
	{
		virtual void print(std::ostream &os) const;
		virtual std::uint16_t getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			std::uint16_t &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct WordPtr : Argument
	{
		std::unique_ptr<Constant> extra;
		
		explicit WordPtr(std::unique_ptr<Constant> extra);
		virtual void print(std::ostream &os) const;
		virtual std::uint16_t getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			std::uint16_t &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct Word : Argument
	{
		std::unique_ptr<Constant> extra;
		
		explicit Word(std::unique_ptr<Constant> extra);
		virtual void print(std::ostream &os) const;
		virtual std::uint16_t getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			std::uint16_t &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct Statement
	{
		virtual ~Statement();
		virtual void print(std::ostream &os) const = 0;
		virtual std::uint16_t getSizeInMemory() const = 0;
		virtual void compile(
			IMemoryWriter &destination,
			ILabelResolver &resolver) const = 0;
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
		virtual std::uint16_t getSizeInMemory() const;
		virtual void compile(
			IMemoryWriter &destination,
			ILabelResolver &resolver
			) const;
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
		virtual std::uint16_t getSizeInMemory() const;
		virtual void compile(
			IMemoryWriter &destination,
			ILabelResolver &resolver
			) const;
	};
	
	struct Data : Statement
	{
		std::vector<std::uint16_t> value;
		
		explicit Data(std::vector<std::uint16_t> value);
		virtual void print(std::ostream &os) const;
		virtual std::uint16_t getSizeInMemory() const;
		virtual void compile(
			IMemoryWriter &destination,
			ILabelResolver &resolver
			) const;
	};
	
	struct Line
	{
		std::string label;
		std::unique_ptr<Statement> statement;
		SourceIterator begin;
		
		Line();
		explicit Line(
			std::string label,
			std::unique_ptr<Statement> statement,
			SourceIterator begin
			);
		Line(Line &&other);
		Line &operator = (Line &&other);
		void swap(Line &other);
		std::uint16_t getSizeInMemory() const;
	};
	
	struct Parser
	{
		explicit Parser(
			Scanner &scanner
			);
		Scanner &getScanner() const;
		bool parseLine(Line &line);
		void resetCache();
		
	private:
	
		Scanner &m_scanner;
		Token m_cachedToken;
		bool m_isTokenCached;
		
		Token peekToken();
		Token popToken();
		std::unique_ptr<Statement> parseBinaryStatement(TokenId operation);
		std::unique_ptr<Statement> parseUnaryStatement(TokenId operation);
		std::unique_ptr<Statement> parseData();
		std::unique_ptr<Argument> parseArgument();
		void expectRightBracket();
	};
}


#endif
