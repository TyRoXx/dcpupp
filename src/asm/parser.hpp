#ifndef DCPUPP_ASM_PARSER_HPP
#define DCPUPP_ASM_PARSER_HPP


#include "common/operations.hpp"
#include "common/types.hpp"
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
		SynErr_UniversalRegisterExpected,
		SynErr_ReservedSizeExpected,
	};
	
	struct SyntaxException : Exception
	{
		SyntaxErrorCode error;
		
		explicit SyntaxException(
			SourceIterator position,
			SyntaxErrorCode error
			);
	};
	
	enum SemanticErrorCode
	{
		SemErr_UnknownIdentifier,
	};
	
	struct SemanticException : Exception
	{
		SemanticErrorCode error;
		
		explicit SemanticException(
			SourceIterator position,
			SemanticErrorCode error
			);
	};
	
	enum
	{
		UniversalRegisterCount = 8,
	};
	
	enum ArgumentType
	{
		Arg_Register = 0x00,
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
		virtual void write(Word value) = 0;
		virtual void reserve(Word size) = 0;
	};
	
	struct ILabelResolver
	{
		virtual ~ILabelResolver();
		virtual bool resolve(const std::string &name, Word &value) const = 0;
	};
	
	struct Argument
	{
		virtual ~Argument();
		virtual void print(std::ostream &os) const = 0;
		virtual Word getExtraWordCount() const = 0;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			Word &extra,
			ILabelResolver &resolver
			) const = 0;
	};
	
	struct Constant
	{
		virtual ~Constant();
		virtual bool isBelow(Word value) const = 0;
		virtual Word getValue(const ILabelResolver &resolver) const = 0;
		virtual void print(std::ostream &os) const = 0;
	};
	
	struct NumericConstant : Constant
	{
		Word value;
		
		explicit NumericConstant(Word value);
		virtual bool isBelow(Word value) const;
		virtual Word getValue(const ILabelResolver &resolver) const;
		virtual void print(std::ostream &os) const;
	};
	
	struct LabelConstant : Constant
	{
		std::string name;
		SourceIterator position;
		
		explicit LabelConstant(std::string name, SourceIterator position);
		virtual bool isBelow(Word value) const;
		virtual Word getValue(const ILabelResolver &resolver) const;
		virtual void print(std::ostream &os) const;
	};
	
	struct RegisterArgument : Argument
	{
		unsigned id;
		
		explicit RegisterArgument(unsigned id);
		virtual void print(std::ostream &os) const;
		virtual Word getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			Word &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct RegisterPtrArgument : Argument
	{
		unsigned id;
		
		explicit RegisterPtrArgument(unsigned id);
		virtual void print(std::ostream &os) const;
		virtual Word getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			Word &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct RegisterWordPtrArgument : Argument
	{
		unsigned id;
		std::unique_ptr<Constant> extra;
		
		explicit RegisterWordPtrArgument(
			unsigned id,
			std::unique_ptr<Constant> extra
			);
		virtual void print(std::ostream &os) const;
		virtual Word getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			Word &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct PopArgument : Argument
	{
		virtual void print(std::ostream &os) const;
		virtual Word getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			Word &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct PeekArgument : Argument
	{
		virtual void print(std::ostream &os) const;
		virtual Word getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			Word &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct PushArgument : Argument
	{
		virtual void print(std::ostream &os) const;
		virtual Word getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			Word &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct SPArgument : Argument
	{
		virtual void print(std::ostream &os) const;
		virtual Word getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			Word &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct PCArgument : Argument
	{
		virtual void print(std::ostream &os) const;
		virtual Word getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			Word &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct OArgument : Argument
	{
		virtual void print(std::ostream &os) const;
		virtual Word getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			Word &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct WordPtrArgument : Argument
	{
		std::unique_ptr<Constant> extra;
		
		explicit WordPtrArgument(std::unique_ptr<Constant> extra);
		virtual void print(std::ostream &os) const;
		virtual Word getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			Word &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct WordArgument : Argument
	{
		std::unique_ptr<Constant> extra;
		
		explicit WordArgument(std::unique_ptr<Constant> extra);
		virtual void print(std::ostream &os) const;
		virtual Word getExtraWordCount() const;
		virtual bool hasExtraWord(
			unsigned &typeCode,
			Word &extra,
			ILabelResolver &resolver
			) const;
	};
	
	struct Statement
	{
		virtual ~Statement();
		virtual void print(std::ostream &os) const = 0;
		virtual Word getSizeInMemory() const = 0;
		virtual void compile(
			IMemoryWriter &destination,
			ILabelResolver &resolver) const = 0;
	};
	
	struct UnaryStatement : Statement
	{
		NonBasicOperationId operation;
		std::unique_ptr<Argument> argument;
		
		explicit UnaryStatement(
			NonBasicOperationId operation,
			std::unique_ptr<Argument> argument
			);
		virtual void print(std::ostream &os) const;
		virtual Word getSizeInMemory() const;
		virtual void compile(
			IMemoryWriter &destination,
			ILabelResolver &resolver
			) const;
	};
	
	struct BinaryStatement : Statement
	{
		OperationId operation;
		std::unique_ptr<Argument> a, b;
		
		explicit BinaryStatement(
			OperationId operation,
			std::unique_ptr<Argument> a,
			std::unique_ptr<Argument> b
			);
		virtual void print(std::ostream &os) const;
		virtual Word getSizeInMemory() const;
		virtual void compile(
			IMemoryWriter &destination,
			ILabelResolver &resolver
			) const;
	};
	
	struct Data : Statement
	{
		struct IElement;
		typedef std::vector<std::unique_ptr<IElement>> ValueElements;
		
		ValueElements value;
		
		explicit Data(ValueElements value);
		~Data();
		virtual void print(std::ostream &os) const;
		virtual Word getSizeInMemory() const;
		virtual void compile(
			IMemoryWriter &destination,
			ILabelResolver &resolver
			) const;
		
		static std::unique_ptr<IElement> createFixedElement(
			std::vector<Word> value);
		static std::unique_ptr<IElement> createSymbolElement(
			std::string name, SourceIterator position);
	};

	struct ReserveStatement : Statement
	{
		explicit ReserveStatement(Word size);
		virtual void print(std::ostream &os) const;
		virtual Word getSizeInMemory() const;
		virtual void compile(
			IMemoryWriter &destination,
			ILabelResolver &resolver
			) const;

	private:

		Word m_size;
	};
	
	struct Line
	{
		std::string label;
		std::unique_ptr<Statement> statement;
		SourceIterator begin;
		
		explicit Line(
			std::string label,
			std::unique_ptr<Statement> statement,
			SourceIterator begin
			);
		Line(Line &&other);
		Line &operator = (Line &&other);
		void swap(Line &other);
		Word getSizeInMemory() const;
	};
	
	struct Parser
	{
		explicit Parser(
			Scanner &scanner
			);
		Scanner &getScanner() const;
		Line parseLine();
		void resetCache();
		
	private:
	
		Scanner &m_scanner;
		Token m_cachedToken;
		bool m_isTokenCached;
		
		Token peekToken();
		Token popToken();
		std::unique_ptr<Statement> parseBinaryStatement(OperationId operation);
		std::unique_ptr<Statement> parseUnaryStatement(NonBasicOperationId operation);
		std::unique_ptr<Statement> parseData();
		std::unique_ptr<Statement> parseReserve();
		std::unique_ptr<Argument> parseArgument();
		void expectRightBracket();
	};
}


#endif
