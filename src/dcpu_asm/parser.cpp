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
	
		
	Line::Line(
		std::string label,
		std::unique_ptr<Statement> statement)
		: label(std::move(label))
		, statement(std::move(statement))
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
	}
		
		
	Parser::Parser(
		Scanner &scanner
		)
		: m_scanner(scanner)
	{
	}
	
	Line Parser::parseLine()
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
		
		return Line(
			std::move(label),
			std::move(statement)
			);
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
	}
	
	std::unique_ptr<Argument> Parser::parseArgument()
	{
	}
}

