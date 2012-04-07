#include "scanner.hpp"
#include <cassert>
#include <algorithm>


namespace dcpupp
{
	Token::Token()
	{
	}
	
	Token::Token(
		TokenId type,
		SourceIterator begin,
		SourceIterator end)
		: type(type)
		, begin(begin)
		, end(end)
	{
	}
	

	Exception::Exception(
		const char *message,
		SourceIterator position
		)
		: std::runtime_error(message)
		, position(position)
	{
	}
	
	
	LexicalException::LexicalException(
		SourceIterator position,
		LexicalErrorCode error)
		: Exception("Lexical exception", position)
		, error(error)
	{
	}
	
	
	Scanner::Scanner(
		SourceIterator begin,
		SourceIterator end)
		: m_begin(begin)
		, m_pos(begin)
		, m_end(end)
	{
	}
	
	static bool isAlphabetic(char c)
	{
		return
			(c >= 'a' && c <= 'z') ||
			(c >= 'A' && c <= 'Z');
	}
	
	static bool isAlphaNumeric(char c)
	{
		return isAlphabetic(c) ||
			(c >= '0' && c <= '9');
	}
	
	static bool isDigit(char c, unsigned base)
	{
		switch (base)
		{
		case 16:
			if ((c >= 'a' && c <= 'f') ||
				(c >= 'A' && c <= 'F'))
			{
				return true;
			}
			//fall through
		default:
			if (c >= '0' && c < ('0' + base))
			{
				return true;
			}
			break;
		}
		return false;
	}
	
	struct Keyword
	{
		std::string name;
		TokenId token;
	};
	
	static const Keyword Keywords[] =
	{
		{"SET", Tk_Set},
		{"ADD", Tk_Add},
		{"SUB", Tk_Sub},
		{"MUL", Tk_Mul},
		{"DIV", Tk_Div},
		{"MOD", Tk_Mod},
		{"SHL", Tk_Shl},
		{"SHR", Tk_Shr},
		{"AND", Tk_And},
		{"BOR", Tk_Bor},
		{"XOR", Tk_Xor},
		{"IFE", Tk_Ife},
		{"IFN", Tk_Ifn},
		{"IFG", Tk_Ifg},
		{"IFB", Tk_Ifb},
		{"JSR", Tk_Jsr},
		{"DAT", Tk_Dat},
		{"PUSH", Tk_Push},
		{"PEEK", Tk_Peek},
		{"POP", Tk_Pop},
		{"SP", Tk_SP},
		{"PC", Tk_PC},
		{"O", Tk_O},
		{"A", Tk_A},
		{"B", Tk_B},
		{"C", Tk_C},
		{"X", Tk_X},
		{"Y", Tk_Y},
		{"Z", Tk_Z},
		{"I", Tk_I},
		{"J", Tk_J},
	};
	
	Token Scanner::nextToken()
	{
		skipWhitespace();
		
		if (m_pos == m_end)
		{
			return Token(Tk_EndOfFile, m_end, m_end);
		}
		
		const char firstChar = *m_pos;
		
		switch (firstChar)
		{
		case ':': return eatToken(Tk_Colon);
		case ',': return eatToken(Tk_Comma);
		case '+': return eatToken(Tk_Plus);
		case '[': return eatToken(Tk_LeftBracket);
		case ']': return eatToken(Tk_RightBracket);
		case '"':
			{
				++m_pos;
				const auto strBegin = m_pos;
				while ((m_pos != m_end) &&
					(*m_pos != '"'))
				{
					++m_pos;
				}
				const auto strEnd = m_pos;
				++m_pos;
				return Token(Tk_String, strBegin, strEnd);
			}
			
		default:
			{
				if (isAlphabetic(firstChar) || (firstChar == '_'))
				{
					const auto idBegin = m_pos;
					do
					{
						++m_pos;
					}
					while ((m_pos != m_end) &&
						(
							isAlphaNumeric(*m_pos) ||
							(*m_pos == '_')
						));
					const auto idEnd = m_pos;
					std::string identifier(idBegin, idEnd);
					std::transform(
						identifier.begin(),
						identifier.end(),
						identifier.begin(),
						[](char c) { return std::toupper(c); });
					for (size_t i = 0; i < sizeof(Keywords)/sizeof(Keywords[0]); ++i)
					{
						const auto &keyword = Keywords[i];
						if (keyword.name == identifier)
						{
							return Token(keyword.token, idBegin, idEnd);
						}
					}
					return Token(Tk_Identifier, idBegin, idEnd);
				}
				
				else if (isDigit(firstChar, 10))
				{
					if (firstChar == '0')
					{
						const auto literalBegin = m_pos;
						++m_pos;
						
						//a single zero digit
						if (m_pos == m_end)
						{
							return Token(Tk_Decimal, m_pos - 1, m_pos);
						}
						
						//hex, binary
						if (*m_pos == 'x' ||
							*m_pos == 'b')
						{
							const auto base = (*m_pos == 'x' ? 16 : 2);
							
							++m_pos;
							if (m_pos == m_end ||
								!isDigit(*m_pos, base))
							{
								throw LexicalException(literalBegin, LexErr_IncompleteInteger);
							}
							
							const auto literalBegin = m_pos;
							do
							{
								++m_pos;
							}
							while ((m_pos != m_end) &&
								isDigit(*m_pos, base));
							const auto literalEnd = m_pos;
							expectNonAlphaNumeric();
							return Token(
								base == 16 ? Tk_Hexadecimal : Tk_Binary,
								literalBegin,
								literalEnd);
						}
						
						//octal
						else if (isDigit(*m_pos, 8))
						{
							const auto literalBegin = m_pos;
							do
							{
								++m_pos;
							}
							while ((m_pos != m_end) &&
								isDigit(*m_pos, 8));
							const auto literalEnd = m_pos;
							expectNonAlphaNumeric();
							return Token(
								Tk_Octal,
								literalBegin,
								literalEnd);
						}
						
						//a single zero digit
						else
						{
							return Token(Tk_Decimal, m_pos - 1, m_pos);
						}
					}
					else
					{
						//decimal
						const auto literalBegin = m_pos;
						do
						{
							++m_pos;
						}
						while ((m_pos != m_end) &&
							isDigit(*m_pos, 10));
						const auto literalEnd = m_pos;
						expectNonAlphaNumeric();
						return Token(
							Tk_Decimal,
							literalBegin,
							literalEnd);
					}
				}
				
				throw LexicalException(m_pos, LexErr_InvalidCharacter);
			}
		}
	}
	
	void Scanner::skipLine()
	{
		while (m_pos != m_end)
		{
			if (*m_pos == '\n')
			{
				++m_pos;
				break;
			}
			
			++m_pos;
		}
	}
	
	
	static bool isWhitespace(char c)
	{
		return (c >= 0 && c <= ' ');
	}
	
	void Scanner::skipWhitespace()
	{
		while (m_pos != m_end)
		{
			if (isWhitespace(*m_pos))
			{
				++m_pos;
			}
			else if (*m_pos == ';')
			{
				++m_pos;
				skipLine();
			}
			else
			{
				break;
			}
		}
	}
	
	void Scanner::expectNonAlphaNumeric()
	{
		if (m_pos == m_end)
		{
			return;
		}
		
		if (isAlphaNumeric(*m_pos) ||
			(*m_pos == '_'))
		{
			throw LexicalException(m_pos, LexErr_UnexpectedCharacter);
		}
	}
	
	Token Scanner::eatToken(TokenId id)
	{
		++m_pos;
		return Token(id, m_pos - 1, m_pos);
	}
}

