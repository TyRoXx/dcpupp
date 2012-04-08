#include "parser.hpp"
#include <cassert>
#include <string>


namespace dcpupp
{
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
	
	bool NumericConstant::isBelow(std::uint16_t value) const
	{
		return (this->value < value);
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
	
	bool LabelConstant::isBelow(std::uint16_t value) const
	{
		return false; //unknown at this time
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


	RegisterArgument::RegisterArgument(unsigned id)
		: id(id)
	{
	}
	
	static const char * const UniversalRegisterNames = "ABCXYZIJ";
	
	void RegisterArgument::print(std::ostream &os) const
	{
		os << UniversalRegisterNames[id];
	}
	
	std::uint16_t RegisterArgument::getExtraWordCount() const
	{
		return 0;
	}
	
	bool RegisterArgument::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		typeCode = id;
		return false;
	}
	
	
	RegisterPtrArgument::RegisterPtrArgument(unsigned id)
		: id(id)
	{
	}
	
	void RegisterPtrArgument::print(std::ostream &os) const
	{
		os << "[" << UniversalRegisterNames[id] << "]";
	}
	
	std::uint16_t RegisterPtrArgument::getExtraWordCount() const
	{
		return 0;
	}
	
	bool RegisterPtrArgument::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		typeCode = (8 + id);
		return false;
	}
	
	
	RegisterWordPtrArgument::RegisterWordPtrArgument(
		unsigned id,
		std::unique_ptr<Constant> extra
		)
		: id(id)
		, extra(std::move(extra))
	{
	}
	
	void RegisterWordPtrArgument::print(std::ostream &os) const
	{
		extra->print(os);
		os << "+" << UniversalRegisterNames[id];
	}
	
	std::uint16_t RegisterWordPtrArgument::getExtraWordCount() const
	{
		return 1;
	}
	
	bool RegisterWordPtrArgument::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		typeCode = (16 + id);
		extra = this->extra->getValue(resolver);
		return true;
	}
	
	
	void PopArgument::print(std::ostream &os) const
	{
		os << "POP";
	}
	
	std::uint16_t PopArgument::getExtraWordCount() const
	{
		return 0;
	}
	
	bool PopArgument::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		typeCode = 0x18;
		return false;
	}
	
	
	void PeekArgument::print(std::ostream &os) const
	{
		os << "PEEK";
	}
	
	std::uint16_t PeekArgument::getExtraWordCount() const
	{
		return 0;
	}
	
	bool PeekArgument::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		typeCode = 0x19;
		return false;
	}
	
	
	void PushArgument::print(std::ostream &os) const
	{
		os << "PUSH";
	}
	
	std::uint16_t PushArgument::getExtraWordCount() const
	{
		return 0;
	}
	
	bool PushArgument::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		typeCode = 0x1a;
		return false;
	}
			
			
	void SPArgument::print(std::ostream &os) const
	{
		os << "SP";
	}
	
	std::uint16_t SPArgument::getExtraWordCount() const
	{
		return 0;
	}
	
	bool SPArgument::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		typeCode = 0x1b;
		return false;
	}
			
			
	void PCArgument::print(std::ostream &os) const
	{
		os << "PC";
	}
	
	std::uint16_t PCArgument::getExtraWordCount() const
	{
		return 0;
	}
	
	bool PCArgument::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		typeCode = 0x1c;
		return false;
	}
			
			
	void OArgument::print(std::ostream &os) const
	{
		os << "O";
	}
	
	std::uint16_t OArgument::getExtraWordCount() const
	{
		return 0;
	}
	
	bool OArgument::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		typeCode = 0x1d;
		return false;
	}
			
	
	WordPtrArgument::WordPtrArgument(std::unique_ptr<Constant> extra)
		: extra(std::move(extra))
	{
	}
	
	void WordPtrArgument::print(std::ostream &os) const
	{
		os << "[";
		extra->print(os);
		os << "]";
	}
	
	std::uint16_t WordPtrArgument::getExtraWordCount() const
	{
		return 1;
	}
	
	bool WordPtrArgument::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		typeCode = 0x1e;
		extra = this->extra->getValue(resolver);
		return true;
	}
	
	
	WordArgument::WordArgument(std::unique_ptr<Constant> extra)
		: extra(std::move(extra))
	{
	}
	
	void WordArgument::print(std::ostream &os) const
	{
		extra->print(os);
	}
	
	std::uint16_t WordArgument::getExtraWordCount() const
	{
		return extra->isBelow(32) ? 0 : 1;
	}
	
	bool WordArgument::hasExtraWord(
		unsigned &typeCode,
		std::uint16_t &extra,
		ILabelResolver &resolver
		) const
	{
		const auto value = this->extra->getValue(resolver);
		if (this->extra->isBelow(32))
		{
			assert(value < 32);
			typeCode = 0x20 + value;
			return false;
		}
		else
		{
			typeCode = 0x1f;
			extra = value;
			return true;
		}
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
		const unsigned opcode = 0;
		unsigned a_code = (operation - Tk_Jsr + 1), b_code;
		std::uint16_t b_extra;
		const bool hasBExtra = argument->hasExtraWord(b_code, b_extra, resolver);
		
		destination.write(
			(b_code << 10) |
			(a_code << 4) |
			opcode
			);
		
		if (hasBExtra)
		{
			destination.write(b_extra);
		}
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
	
	
	Data::Data(std::vector<std::uint16_t> value)
		: value(std::move(value))
	{
	}
	
	void Data::print(std::ostream &os) const
	{
		bool comma = false;
		for (auto i = value.begin(); i != value.end(); ++i)
		{
			if (comma) os << ", "; else comma = true;
			os << *i;
		}
	}
	
	std::uint16_t Data::getSizeInMemory() const
	{
		return value.size();
	}
	
	void Data::compile(
		IMemoryWriter &destination,
		ILabelResolver &resolver
		) const
	{
		for (auto i = value.begin(); i != value.end(); ++i)
		{
			destination.write(*i);
		}
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
		: label(std::move(other.label))
		, statement(std::move(other.statement))
		, begin(other.begin)
	{
	}
	
	Line &Line::operator = (Line &&other)
	{
		if (this != &other)
		{
			label = std::move(other.label);
			statement = std::move(other.statement);
			begin = other.begin;
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
		, m_isTokenCached(false)
	{
	}
	
	Scanner &Parser::getScanner() const
	{
		return m_scanner;
	}
	
	Line Parser::parseLine()
	{
		std::string label;
		
		Token first = popToken();
		const auto lineBegin = first.begin;
		
		if (first.type == Tk_Colon)
		{
			const Token labelToken = popToken();
			if (labelToken.type != Tk_Identifier)
			{
				throw SyntaxException(labelToken.begin, SynErr_LabelNameExpected);
			}
			
			label.assign(
				labelToken.begin,
				labelToken.end);
				
			first = peekToken();
			if (first.type == Tk_Colon)
			{
				return Line(
					std::move(label),
					std::unique_ptr<Statement>(),
					lineBegin
					);
			}
			
			popToken();
		}
		
		else if (first.type == Tk_EndOfFile)
		{
			return Line(
				label,
				std::unique_ptr<Statement>(),
				lineBegin);
		}
		
		std::unique_ptr<Statement> statement;
		
		const Token keyword = first;
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
			
		case Tk_EndOfFile:
			break;
					
		default:
			throw SyntaxException(keyword.begin, SynErr_KeywordExpected);
		}
		
		return Line(
			std::move(label),
			std::move(statement),
			lineBegin
			);
	}
	
	void Parser::resetCache()
	{
		m_isTokenCached = false;
	}
	
	
	Token Parser::peekToken()
	{
		assert(!m_isTokenCached);
		m_cachedToken = m_scanner.nextToken();
		m_isTokenCached = true;
		return m_cachedToken;
	}
	
	Token Parser::popToken()
	{
		if (m_isTokenCached)
		{
			m_isTokenCached = false;
			return m_cachedToken;
		}
		
		return m_scanner.nextToken();
	}
	
	std::unique_ptr<Statement> Parser::parseBinaryStatement(TokenId operation)
	{
		auto a = parseArgument();
		
		const Token comma = popToken();
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
		std::vector<std::uint16_t> data;
		
		for (;;)
		{
			const Token current = popToken();
			
			if (current.type == Tk_String)
			{
				for (auto i = current.begin; i != current.end; ++i)
				{
					data.push_back(*i);
				}
			}
			else if (isIntegerLiteral(current.type))
			{
				data.push_back(getIntegerValue(current));
			}
			else
			{
				throw SyntaxException(current.begin, SynErr_DataExpected);
			}
			
			const Token comma = peekToken();
			if (comma.type == Tk_Comma)
			{
				popToken();
				continue;
			}
			else
			{
				break;
			}
		}
		
		return std::unique_ptr<Statement>(
			new Data(std::move(data)));
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
	
	std::unique_ptr<Argument> Parser::parseArgument()
	{
		const Token firstToken = popToken();
		switch (firstToken.type)
		{
		case Tk_LeftBracket:
			{
				auto secondToken = popToken();
				if (isUniversalRegister(secondToken.type))
				{
					expectRightBracket();
					return std::unique_ptr<Argument>(
						new RegisterPtrArgument(secondToken.type - Tk_A));
				}
				else if (secondToken.type == Tk_Identifier ||
					isIntegerLiteral(secondToken.type))
				{
					std::unique_ptr<Constant> constant;
					if (secondToken.type == Tk_Identifier)
					{
						constant.reset(new LabelConstant(std::string(secondToken.begin, secondToken.end)));
					}
					else
					{
						constant.reset(new NumericConstant(getIntegerValue(secondToken)));
					}
						
					const Token plusToken = peekToken();
					if (plusToken.type == Tk_Plus)
					{
						popToken();
						const Token register_ = popToken();
						if (!isUniversalRegister(register_.type))
						{
							throw SyntaxException(register_.begin,
								SynErr_UniversalRegisterExpected);
						}
						expectRightBracket();
						return std::unique_ptr<Argument>(
							new RegisterWordPtrArgument(
								register_.type - Tk_A,
								std::move(constant)));
					}
					else
					{
						expectRightBracket();
						return std::unique_ptr<Argument>(
							new WordPtrArgument(std::move(constant)));
					}
					
					expectRightBracket();
					return std::unique_ptr<Argument>(
						new WordPtrArgument(std::move(constant)));
				}
				
				throw SyntaxException(firstToken.begin, SynErr_ArgumentExpected);
			}
			
		case Tk_Identifier:
			{
				return std::unique_ptr<Argument>(
					new WordArgument(std::unique_ptr<Constant>(
						new LabelConstant(std::string(firstToken.begin, firstToken.end)))));
			}
			
		case Tk_Pop:
			return std::unique_ptr<Argument>(new PopArgument);
			
		case Tk_Peek:
			return std::unique_ptr<Argument>(new PeekArgument);
			
		case Tk_Push:
			return std::unique_ptr<Argument>(new PushArgument);
			
		case Tk_SP:
			return std::unique_ptr<Argument>(new SPArgument);
			
		case Tk_PC:
			return std::unique_ptr<Argument>(new PCArgument);
			
		case Tk_O:
			return std::unique_ptr<Argument>(new OArgument);
			
		default:
			if (isUniversalRegister(firstToken.type))
			{
				return std::unique_ptr<Argument>(
					new RegisterArgument(firstToken.type - Tk_A));
			}
			else if (isIntegerLiteral(firstToken.type))
			{
				return std::unique_ptr<Argument>(
					new WordArgument(std::unique_ptr<Constant>(
						new NumericConstant(getIntegerValue(firstToken)))));
			}
				
			throw SyntaxException(firstToken.begin, SynErr_ArgumentExpected);
		}
	}
	
	void Parser::expectRightBracket()
	{
		const auto bracketToken = popToken();
		if (bracketToken.type != Tk_RightBracket)
		{
			throw SyntaxException(bracketToken.begin, SynErr_MissingRightBracket);
		}
	}
}

