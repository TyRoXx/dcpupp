#include "parser.hpp"
#include <cassert>
#include <string>


namespace dcpupp
{
	SyntaxException::SyntaxException(
		SourceIterator position,
		SyntaxErrorCode error
		)
		: Exception("Syntax error", position)
		, error(error)
	{
	}
	
	
	IMemoryWriter::~IMemoryWriter()
	{
	}
	
	
	ILabelResolver::~ILabelResolver()
	{
	}
	
	
	Argument::~Argument()
	{
	}
	
	
	Constant::~Constant()
	{
	}
	
	
	NumericConstant::NumericConstant(std::uint16_t value)
		: value(value)
	{
	}
	
	std::uint16_t NumericConstant::getValue(const ILabelResolver &resolver) const
	{
		return value;
	}
	
	void NumericConstant::print(std::ostream &os) const
	{
		os << value;
	}
	
	
	LabelConstant::LabelConstant(std::string name)
		: name(std::move(name))
	{
	}
	
	std::uint16_t LabelConstant::getValue(const ILabelResolver &resolver) const
	{
		std::uint16_t value;
		if (!resolver.resolve(name, value))
		{
			assert(!"TODO");
		}
		return value;
	}
	
	void LabelConstant::print(std::ostream &os) const
	{
		os << name;
	}


	Register::Register(unsigned id)
		: id(id)
	{
	}
	
	static const char * const UniversalRegisterNames = "ABCXYZIJ";
	
	void Register::print(std::ostream &os) const
	{
		os << UniversalRegisterNames[id];
	}
	
	std::uint16_t Register::getExtraWordCount() const
	{
		return 0;
	}
	
	bool Register::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		typeCode = id;
		return false;
	}
	
	
	RegisterPtr::RegisterPtr(unsigned id)
		: id(id)
	{
	}
	
	void RegisterPtr::print(std::ostream &os) const
	{
		os << "[" << UniversalRegisterNames[id] << "]";
	}
	
	std::uint16_t RegisterPtr::getExtraWordCount() const
	{
		return 0;
	}
	
	bool RegisterPtr::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		typeCode = (8 + id);
		return false;
	}
	
	
	RegisterWordPtr::RegisterWordPtr(
		unsigned id,
		std::unique_ptr<Constant> extra
		)
		: id(id)
		, extra(std::move(extra))
	{
	}
	
	void RegisterWordPtr::print(std::ostream &os) const
	{
		extra->print(os);
		os << "+" << UniversalRegisterNames[id];
	}
	
	std::uint16_t RegisterWordPtr::getExtraWordCount() const
	{
		return 1;
	}
	
	bool RegisterWordPtr::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		typeCode = (16 + id);
		extra = this->extra->getValue(resolver);
		return true;
	}
	
	
	WordPtr::WordPtr(std::unique_ptr<Constant> extra)
		: extra(std::move(extra))
	{
	}
	
	void WordPtr::print(std::ostream &os) const
	{
		os << "[";
		extra->print(os);
		os << "]";
	}
	
	std::uint16_t WordPtr::getExtraWordCount() const
	{
		return 1;
	}
	
	bool WordPtr::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		typeCode = 0x1e;
		extra = this->extra->getValue(resolver);
		return true;
	}
	
	
	Word::Word(std::unique_ptr<Constant> extra)
		: extra(std::move(extra))
	{
	}
	
	void Word::print(std::ostream &os) const
	{
		extra->print(os);
	}
	
	std::uint16_t Word::getExtraWordCount() const
	{
		return 1;
	}
	
	bool Word::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		typeCode = 0x1f;
		extra = this->extra->getValue(resolver);
		return true;
	}
			
	
	Statement::~Statement()
	{
	}
	
	
	UnaryStatement::UnaryStatement(
		TokenId operation,
		std::unique_ptr<Argument> argument
		)
		: operation(operation)
		, argument(std::move(argument))
	{
	}
	
	void UnaryStatement::print(std::ostream &os) const
	{
		std::string name;
		switch (operation)
		{
		case Tk_Jsr:
			name = "JSR";
			break;
		
		default:
			assert(false);
			break;
		}
		
		os << name << " ";
		argument->print(os);
	}
	
	std::uint16_t UnaryStatement::getSizeInMemory() const
	{
		return (1 + argument->getExtraWordCount());
	}
	
	void UnaryStatement::compile(
		IMemoryWriter &destination,
		ILabelResolver &resolver) const
	{
		assert(!"TODO");
	}
	
	
	BinaryStatement::BinaryStatement(
		TokenId operation,
		std::unique_ptr<Argument> a,
		std::unique_ptr<Argument> b
		)
		: operation(operation)
		, a(std::move(a))
		, b(std::move(b))
	{
	}
	
	void BinaryStatement::print(std::ostream &os) const
	{
		std::string name;
		switch (operation)
		{
		case Tk_Set: name = "SET"; break;
		case Tk_Add: name = "ADD"; break;
		case Tk_Sub: name = "SUB"; break;
		case Tk_Mul: name = "MUL"; break;
		case Tk_Div: name = "DIV"; break;
		case Tk_Mod: name = "MOD"; break;
		case Tk_Shl: name = "SHL"; break;
		case Tk_Shr: name = "SHR"; break;
		case Tk_And: name = "AND"; break;
		case Tk_Bor: name = "BOR"; break;
		case Tk_Xor: name = "XOR"; break;
		case Tk_Ife: name = "IFE"; break;
		case Tk_Ifn: name = "IFN"; break;
		case Tk_Ifg: name = "IFG"; break;
		case Tk_Ifb: name = "IFB"; break;
		
		default:
			assert(false);
			break;
		}
		
		os << name << " ";
		a->print(os);
		os << ", ";
		b->print(os);
	}
	
	std::uint16_t BinaryStatement::getSizeInMemory() const
	{
		return (1 + a->getExtraWordCount() + b->getExtraWordCount());
	}
	
	void BinaryStatement::compile(
		IMemoryWriter &destination,
		ILabelResolver &resolver) const
	{
		const unsigned opcode = (operation - Tk_Set + 1);
		unsigned a_code, b_code;
		std::uint16_t a_extra, b_extra;
		const bool hasAExtra = a->hasExtraWord(a_code, a_extra, resolver);
		const bool hasBExtra = b->hasExtraWord(b_code, b_extra, resolver);
		
		destination.write(
			(b_code << 10) |
			(a_code << 4) |
			opcode
			);
			
		if (hasAExtra)
		{
			destination.write(a_extra);
		}
		
		if (hasBExtra)
		{
			destination.write(b_extra);
		}
	}
	
	
	Line::Line()
	{
	}
	
	Line::Line(
		std::string label,
		std::unique_ptr<Statement> statement,
		SourceIterator begin
		)
		: label(std::move(label))
		, statement(std::move(statement))
		, begin(begin)
	{
	}
	
	Line::Line(Line &&other)
	{
		swap(other);
	}
	
	Line &Line::operator = (Line &&other)
	{
		if (this != &other)
		{
			swap(other);
		}
		return *this;
	}
	
	void Line::swap(Line &other)
	{
		label.swap(other.label);
		statement.swap(other.statement);
		std::swap(begin, other.begin);
	}
	
	std::uint16_t Line::getSizeInMemory() const
	{
		return statement ? statement->getSizeInMemory() : 0;
	}
		
		
	Parser::Parser(
		Scanner &scanner
		)
		: m_scanner(scanner)
	{
	}
	
	Scanner &Parser::getScanner() const
	{
		return m_scanner;
	}
	
	bool Parser::parseLine(Line &line)
	{
		std::string label;
		
		const Token first = m_scanner.nextToken();
		if (first.type == Tk_Colon)
		{
			const Token labelToken = m_scanner.nextToken();
			if (labelToken.type != Tk_Identifier)
			{
				throw SyntaxException(labelToken.begin, SynErr_LabelNameExpected);
			}
			
			label.assign(
				labelToken.begin,
				labelToken.end);
		}
		
		else if (first.type == Tk_EndOfFile)
		{
			return false;
		}
		
		std::unique_ptr<Statement> statement;
		
		const Token keyword = m_scanner.nextToken();
		
		switch (keyword.type)
		{
		case Tk_Set:
		case Tk_Add:
		case Tk_Sub:
		case Tk_Mul:
		case Tk_Div:
		case Tk_Mod:
		case Tk_Shl:
		case Tk_Shr:
		case Tk_And:
		case Tk_Bor:
		case Tk_Xor:
		case Tk_Ife:
		case Tk_Ifn:
		case Tk_Ifg:
		case Tk_Ifb:
			statement = parseBinaryStatement(keyword.type);
			assert(statement);
			break;
			
		case Tk_Jsr:
			statement = parseUnaryStatement(keyword.type);
			assert(statement);
			break;
		
		case Tk_Dat:
			statement = parseData();
			assert(statement);
			break;
			
		default:
			throw SyntaxException(keyword.begin, SynErr_KeywordExpected);
		}
		
		line = Line(
			std::move(label),
			std::move(statement),
			first.begin
			);
		return true;
	}
	
	
	std::unique_ptr<Statement> Parser::parseBinaryStatement(TokenId operation)
	{
		auto a = parseArgument();
		
		const Token comma = m_scanner.nextToken();
		if (comma.type != Tk_Comma)
		{
			throw SyntaxException(comma.begin, SynErr_CommaExpected);
		}
		
		auto b = parseArgument();
		
		return std::unique_ptr<Statement>(
			new BinaryStatement(operation, std::move(a), std::move(b)));
	}
	
	std::unique_ptr<Statement> Parser::parseUnaryStatement(TokenId operation)
	{
		auto argument = parseArgument();
		return std::unique_ptr<Statement>(
			new UnaryStatement(operation, std::move(argument)));
	}
	
	std::unique_ptr<Statement> Parser::parseData()
	{
		assert(!"TODO");
		return std::unique_ptr<Statement>();
	}
	
	static bool isUniversalRegister(TokenId token)
	{
		switch (token)
		{
		case Tk_A:
		case Tk_B:
		case Tk_C:
		case Tk_X:
		case Tk_Y:
		case Tk_Z:
		case Tk_I:
		case Tk_J:
			return true;
			
		default:
			return false;
		}
	}
	
	static bool isIntegerLiteral(TokenId token)
	{
		switch (token)
		{
		case Tk_Decimal:
		case Tk_Hexadecimal:
		case Tk_Octal:
		case Tk_Binary:
			return true;
			
		default:
			return false;
		}
	}
	
	static unsigned getDigitValue(char c)
	{
		switch (c)
		{
		case '0': return 0;
		case '1': return 1;
		case '2': return 2;
		case '3': return 3;
		case '4': return 4;
		case '5': return 5;
		case '6': return 6;
		case '7': return 7;
		case '8': return 8;
		case '9': return 9;
		case 'a': case 'A': return 10;
		case 'b': case 'B': return 11;
		case 'c': case 'C': return 12;
		case 'd': case 'D': return 13;
		case 'e': case 'E': return 14;
		case 'f': case 'F': return 15;
		default: assert(false); return 0;
		}
	}
	
	static std::uint16_t getIntegerValue(const Token &token)
	{
		unsigned base;
		switch (token.type)
		{
		case Tk_Decimal: base = 10; break;
		case Tk_Hexadecimal: base = 16; break;
		case Tk_Octal: base = 8; break;
		case Tk_Binary: base = 2; break;
		default:
			assert(false);
			return 0;
		}
		
		unsigned value = 0;
		for (auto i = token.begin; i != token.end; ++i)
		{
			value *= base;
			value += getDigitValue(*i);
		}
		
		return static_cast<std::uint16_t>(value);
	}
	
	std::unique_ptr<Argument> Parser::parseArgument()
	{
		const Token firstToken = m_scanner.nextToken();
		switch (firstToken.type)
		{
		case Tk_LeftBracket:
			{
				auto secondToken = m_scanner.nextToken();
				if (isUniversalRegister(secondToken.type))
				{
					expectRightBracket();
					return std::unique_ptr<Argument>(
						new RegisterPtr(secondToken.type - Tk_A));
				}
				else if (secondToken.type == Tk_Identifier)
				{
					expectRightBracket();
					return std::unique_ptr<Argument>(
						new WordPtr(std::unique_ptr<Constant>(
							new LabelConstant(std::string(secondToken.begin, secondToken.end)))));
				}
				else if (isIntegerLiteral(secondToken.type))
				{
					expectRightBracket();
					return std::unique_ptr<Argument>(
						new WordPtr(std::unique_ptr<Constant>(
							new NumericConstant(getIntegerValue(secondToken)))));
				}
				
				throw SyntaxException(firstToken.begin, SynErr_ArgumentExpected);
			}
			
		case Tk_Identifier:
			{
				return std::unique_ptr<Argument>(
					new Word(std::unique_ptr<Constant>(
						new LabelConstant(std::string(firstToken.begin, firstToken.end)))));
				break;
			}
			
		default:
			if (isUniversalRegister(firstToken.type))
			{
				return std::unique_ptr<Argument>(
					new Register(firstToken.type - Tk_A));
			}
			else if (isIntegerLiteral(firstToken.type))
			{
				return std::unique_ptr<Argument>(
					new Word(std::unique_ptr<Constant>(
						new NumericConstant(getIntegerValue(firstToken)))));
			}
				
			throw SyntaxException(firstToken.begin, SynErr_ArgumentExpected);
		}
	}
	
	void Parser::expectRightBracket()
	{
		const auto bracketToken = m_scanner.nextToken();
		if (bracketToken.type != Tk_RightBracket)
		{
			throw SyntaxException(bracketToken.begin, SynErr_MissingRightBracket);
		}
	}
}

