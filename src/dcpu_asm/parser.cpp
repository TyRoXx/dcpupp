#include "parser.hpp"


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
		default:
			throw SyntaxException(keyword.begin, SynErr_KeywordExpected);
		}
		
		return Line(
			std::move(label),
			std::move(statement)
			);
	}
}

