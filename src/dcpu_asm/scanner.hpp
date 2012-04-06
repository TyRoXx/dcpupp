#ifndef DCPUPP_ASM_SCANNER_HPP
#define DCPUPP_ASM_SCANNER_HPP


#include <string>
#include <stdexcept>


namespace dcpupp
{
	enum TokenId
	{
		Tk_Identifier,
		Tk_Decimal,
		Tk_Hexadecimal,
		Tk_Octal,
		Tk_Binary,
		Tk_String,
		Tk_Colon,
		Tk_Comma,
		Tk_Plus,
		Tk_LeftBracket,
		Tk_RightBracket,
		Tk_Set,
		Tk_Add,
		Tk_Sub,
		Tk_Mul,
		Tk_Div,
		Tk_Mod,
		Tk_Shl,
		Tk_Shr,
		Tk_And,
		Tk_Bor,
		Tk_Xor,
		Tk_Ife,
		Tk_Ifn,
		Tk_Ifg,
		Tk_Ifb,
		Tk_Jsr,
		Tk_Dat,
		Tk_Push,
		Tk_Peek,
		Tk_Pop,
		Tk_SP,
		Tk_PC,
		Tk_O,
		Tk_A,
		Tk_B,
		Tk_C,
		Tk_X,
		Tk_Y,
		Tk_Z,
		Tk_I,
		Tk_J,
		Tk_EndOfFile,
	};
	
	typedef std::string::const_iterator SourceIterator;
	
	struct Token
	{
		TokenId type;
		SourceIterator begin, end;
		
		Token();
		Token(
			TokenId type,
			SourceIterator begin,
			SourceIterator end);
	};
	
	enum LexicalErrorCode
	{
		LexErr_InvalidCharacter,
		LexErr_IncompleteInteger,
		LexErr_UnexpectedCharacter,
	};
	
	struct Exception : std::runtime_error
	{
		SourceIterator position;
		
		explicit Exception(
			const char *message,
			SourceIterator position
			);
	};
	
	struct LexicalException : Exception
	{
		LexicalErrorCode error;
		
		explicit LexicalException(
			SourceIterator position,
			LexicalErrorCode error
			);
	};
	
	struct Scanner
	{
		explicit Scanner(
			SourceIterator begin,
			SourceIterator end);
		Token nextToken();
		void skipLine();
		
	private:
	
		SourceIterator m_begin, m_pos, m_end;
		
		void skipWhitespace();
		void expectNonAlphaNumeric();
		Token eatToken(TokenId id);
	};
}


#endif
