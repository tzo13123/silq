// Written in the D programming language.

import std.string, utf = std.utf, std.uni;
import std.stdio, std.conv;
import std.algorithm : startsWith, swap;
import std.traits : EnumMembers;

import core.memory;

import util : lowerf, escape, mallocAppender, toEngNum;

mixin("enum TokenType{"~TokenNames()~"}");

template Tok(string type){mixin(TokImpl());}
template TokChars(TokenType type){mixin(TokCharsImpl());}

bool isAlphaEx(dchar c){
	import std.algorithm : canFind;
	return isAlpha(c)||canFind("₀₁₂₃₄₅₆₇₈₉"d,c);
}

private immutable {
string[2][] complexTokens =
	[["i",     "Identifier"                ],
	 ["``",    "StringLiteral"             ],
	 ["``c",   "StringLiteralC"            ],
	 ["``w",   "StringLiteralW"            ],
	 ["``d",   "StringLiteralD"            ],
	 ["' '",   "CharacterLiteral"          ],
	 ["0",     "IntLiteral"                ],
	 ["0U",    "UintLiteral"               ],
	 ["0L",    "LongLiteral"               ],
	 ["0LU",   "UlongLiteral"              ],
	 [".0f",   "FloatLiteral"              ],
	 [".0",    "DoubleLiteral"             ],
	 [".0L",   "RealLiteral"               ],
	 [".0fi",  "ImaginaryFloatLiteral"     ],
	 [".0i",   "ImaginaryDoubleLiteral"    ],
	 [".0Li",  "ImaginaryLiteral"          ],
	 ["expected", "ExpectedComment"]];
string[2][] simpleTokens = 
	[["/",     "Divide"                    ],
	 ["/=",    "DivideAssign"              ],
	 [".",     "Dot"                       ],
	 ["..",    "DotDot"                    ],
	 ["...",   "DotDotDot"                 ],
	 ["&",     "And"                       ],
	 ["&=",    "AndAssign"                 ],
	 ["&&",    "AndAnd"                    ],
	 ["&&=",   "AndAndAssign"              ],
	 ["|",     "Or"                        ],
	 ["|=",    "OrAssign"                  ],
	 ["||",    "OrOr"                      ],
	 ["||=",   "OrOrAssign"                ],
	 ["-",     "Minus"                     ],
	 ["-=",    "MinusAssign"               ],
	 ["--",    "MinusMinus"                ],
	 ["+",     "Plus"                      ],
	 ["+=",    "PlusAssign"                ],
	 ["++",    "PlusPlus"                  ],
	 ["<",     "Less"                      ],
	 ["<=",    "LessEqual"                 ],
	 ["<<",    "LeftShift"                 ],
	 ["<<=",   "LeftShiftAssign"           ],
	 ["<>",    "LessGreater"               ],
	 ["<>=",   "LessGreaterEqual"          ],
	 [">",     "Greater"                   ],
	 [">=",    "GreaterEqual"              ],
	 [">>=",   "RightShiftAssign"          ],
	 [">>>=",  "LogicalRightShiftAssign"   ],
	 [">>",    "RightShift"                ],
	 [">>>",   "LogicalRightShift"         ],
	 ["!",     "ExclamationMark"           ],
	 ["!=",    "NotEqual"                  ],
	 ["!<>",   "NotLessGreater"            ],
	 ["!<>=",  "Unordered"                 ],
	 ["!<",    "NotLess"                   ],
	 ["!<=",   "NotLessEqual"              ],
	 ["!>",    "NotGreater"                ],
	 ["!>=",   "NotGreaterEqual"           ],
	 ["(",     "LeftParen"                 ],
	 [")",     "RightParen"                ],
	 ["[",     "LeftBracket"               ],
	 ["]",     "RightBracket"              ],
	 ["{",     "LeftCurly"                 ],
	 ["}",     "RightCurly"                ],
	 ["?",     "QuestionMark"              ],
	 [",",     "Comma"                     ],
	 [";",     "Semicolon"                 ],
	 [":",     "Colon"                     ],
	 [":=",    "ColonAssign"               ],
	 ["$",     "Dollar"                    ],
	 ["=",     "Assign"                    ],
	 ["=>",    "GoesTo"                    ],
	 ["==",    "Equal"                     ],
	 ["*",     "Star"                      ],
	 ["*=",    "MultiplyAssign"            ],
	 ["%",     "Modulo"                    ],
	 ["%=",    "ModuloAssign"              ],
	 ["^",     "Xor"                       ],
	 ["^=",    "XorAssign"                 ],
	 ["^^",    "Pow"                       ],
	 ["^^=",   "PowAssign"                 ],
	 ["~",     "Concat"                    ],
	 ["~=",    "ConcatAssign"              ],
	 ["@",     "At"                        ]];
string[2][] specialTokens = 
	[["",      "None",                     ],
	 [" ",     "Whitespace",               ],
	 ["//",    "Comment",                  ],
	 ["///",   "DokComment",               ],
	 ["\n",    "NewLine",                  ], // TODO: incorporate unicode new line support
	 ["Error", "Error"                     ],
	 ["__error","ErrorLiteral"             ],
	 ["EOF",   "Eof"                       ]];
string[2][] compoundTokens = [];

string[] keywords = ["def","true","false","if","else","observe","assert","return","repeat"];


string[2][] tokens = specialTokens ~ complexTokens ~ simpleTokens ~ compoundTokens ~ keywordTokens();
}

private{
auto keywordTokens(){
	immutable(string[2])[] r;
	foreach(i,kw;keywords) r~=[kw,kw~"_"];
	return r;
}

string TokenNames(){
	string r;
	foreach(t;tokens) r~=lowerf(t[1])~",";
	return r;
}

string TokImpl(){
	string r="static if(type==\""~tokens[0][0]~"\") alias TokenType."~lowerf(tokens[0][1])~" Tok;";
	foreach(t;tokens) r~="else static if(type==\""~t[0]~"\") alias TokenType."~lowerf(t[1])~" Tok;";
	r~="else static assert(0,\"unknown Token '\"~type~\"'\");";
	return r;
}

string TokCharsImpl(){
	string r="static if(type==TokenType."~lowerf(tokens[0][1])~") enum TokChars=\""~tokens[0][0]~"\";";
	foreach(t;tokens) r~="else static if(type==TokenType."~lowerf(t[1])~") enum TokChars=\""~t[0]~"\";";
	r~="else static assert(0,\"invalid TokenType \"~to!string(type));";
	return r;
}
}
string TokenTypeToString(TokenType type){
	return tokens[cast(int)type][0];
}

string toString(immutable(Token)[] a){string r;foreach(t;a) r~='['~t.toString()~']'; return r;}

class Source{
	immutable{
		string name;
		string code;
	}
	this(string name, string code)in{auto c=code;assert(c.length>=4&&!c[$-4]&&!c[$-3]&&!c[$-2]&&!c[$-1]);}body{ // four padding zero bytes required because of UTF{
		this.name = name;
		this.code = code[0..$-4]; // don't expose the padding zeros
		sources ~= this;
	}
	string getLineOf(string rep)in{assert(this is get(rep));}body{
		//if(!code.length) return code;
		string before=code.ptr[0..code.length+4][0..rep.ptr-code.ptr];
		string after =code.ptr[0..code.length+4][rep.ptr-code.ptr..$];
		immutable(char)* start=code.ptr, end=code.ptr+code.length;
		foreach_reverse(ref c; before) if(c=='\n'||c=='\r'){start = &c+1; break;}
		foreach(ref c; after) if(c=='\n'||c=='\r'){end = &c; break;}
		return start[0..end-start];
	}
	static Source get(string rep){
		foreach(x; sources) if(rep.ptr>=x.code.ptr && rep.ptr+rep.length<=x.code.ptr+x.code.length+4) return x;
		return null;
	}
	void dispose(){
		foreach(i,x; sources) if(x is this){
			swap(sources[i], sources[$-1]);
			sources=sources[0..$-1];
			sources.assumeSafeAppend();
		}
		assert(0);
	}
	private static Source[] sources;
}

struct Location{
	string rep;    // slice of the code representing the Location
	int line;      // line number at start of location

	// reference to the source the code belongs to
	@property Source source()const{
		auto src = Source.get(rep);
		assert(src, "source for '"~rep~"' not found!");
		return src;
	}
	Location to(const(Location) end)const{// in{assert(end.source is source);}body{
		// in{assert(rep.ptr<=end.rep.ptr);}body{ // requiring that is not robust enough
		if(rep.ptr>end.rep.ptr+end.rep.length) return cast()this;
		return Location(rep.ptr[0..end.rep.ptr-rep.ptr+end.rep.length],line);
	}
}
import std.array;
int getColumn(Location loc, int tabsize){
	int res=0;
	auto l=loc.source.getLineOf(loc.rep);
	for(;!l.empty&&l[0]&&l.ptr<loc.rep.ptr; l.popFront()){
		if(l.front=='\t') res=res-res%tabsize+tabsize;
		else res++;
	}
	return res+1;
}

struct Token{
	TokenType type;
	string toString() const{
		if(type == Tok!"EOF") return "EOF";
		if(loc.rep.length) return loc.rep;
		// TODO: remove boilerplate
		// TODO: get better representations
		switch(type){
			case Tok!"i":
				return name;
			case Tok!"``":
				return '"'~escape(str)~'"';
			case Tok!"``c":
				return '"'~escape(str)~`"c`;
			case Tok!"``w":
				return '"'~escape(str)~`"w`;
			case Tok!"``d":
				return '"'~escape(str)~`"d`;
			case Tok!"' '":
				return '\''~escape(to!string(cast(dchar)int64),false)~'\'';
			case Tok!"0":
				return to!string(cast(int)int64);
			case Tok!"0U":
				return to!string(cast(uint)int64)~'U';
			case Tok!"0L":
				return to!string(cast(long)int64)~'L';
			case Tok!"0LU":
				return to!string(int64)~"LU";
			case Tok!".0f":
				return to!string(flt80)~'f';
			case Tok!".0":
				return to!string(flt80);
			case Tok!".0L":
				return to!string(flt80)~'L';
			case Tok!".0i":
				return to!string(flt80)~'i';
			case Tok!".0fi":
				return to!string(flt80)~"fi";
			case Tok!".0Li":
				return to!string(flt80)~"Li";
			case Tok!"Error":
				return "error: "~str;
			default:
				return tokens[cast(int)type][0];case Tok!"true": return "true";
		}
	}
	union{
		string str, name;  // string literals, identifiers
		ulong int64;       // integer literals
		real flt80;        // float, double, real literals
	}
	Location loc;
}
template token(string t){enum token=Token(Tok!t);} // unions not yet supported

unittest{
static assert({
	foreach(i;simpleTokens){
		string s=i[0];
		bool found = s.length==1;
		foreach(j;simpleTokens) if(j[0] == s[0..$-1]) found = true;
		if(!found) return false;
	}return true;
}(),"Every non-empty prefix of simpleTokens must be a valid token.");
}
string caseSimpleToken(string prefix="", bool needs = false)pure{
	string r;
	int c=0,d=0;
	foreach(i;simpleTokens){string s=i[0]; if(s.startsWith(prefix)) c++;}
	if(c==1) r~=`res[0].type = Tok!"`~prefix~'"'~";\nbreak;\n";
	else{
		if(needs) r~="switch(*p){\n";
		foreach(i;simpleTokens){
			string s = i[0]; if(s[0]=='/' || s[0] == '.') continue; // / can be the start of a comment, . could be the start of a float literal
			if(s.startsWith(prefix) && s.length==prefix.length+1){
				r~=`case '`~s[$-1]~"':\n"~(needs?"p++;\n":"");
				r~=caseSimpleToken(s,true);
			}
		}
		if(needs) r~=`default: res[0].type = Tok!"`~prefix~`"`~";\nbreak;\n}\nbreak;\n";
	}
	return r;
}


auto lex(Source source){ // pure
	return Lexer(source);
}

struct Anchor{
	size_t index;
}

struct Lexer{
	string code; // Manually allocated!
	Token[] buffer;
	Token[] errors;
	Source source;
	size_t n,m; // start and end index in buffer
	size_t s,e; // global start and end index
	size_t numAnchors;  // number of existing anchors for this lexer
	size_t firstAnchor; // first local index that has to remain in buffer
	int line;
	/+invariant(){ // useless because DMD does not test the invariant at the proper time...
		assert(e-s == (m-n+buffer.length)%buffer.length); // relation between (s,e) and (n,m)
		assert(!(buffer.length&buffer.length-1)); // buffer size is always a power of two
		assert(numAnchors||firstAnchor==size_t.max);
	}+/
	//pure: phobos ...
	this(Source src){
		source = src;
		code = src.code.ptr[0..src.code.length+4]; // rely on 4 padding zero bytes
		enum initsize=4096;//685438;//
		buffer = new Token[](initsize);//
		//buffer = (cast(Token*)malloc(Token.sizeof*initsize))[0..initsize];//
		numAnchors=0;
		firstAnchor=size_t.max;
		line=1;
		n=s=0;
		e=lexTo(buffer);
		m=e&buffer.length-1;
		if(src.code.length > int.max) errors~=tokError("no support for sources exceeding 2GB",null),code.length=int.max;
	}
	@property ref const(Token) front()const{return buffer[n];}
	@property bool empty(){return buffer[n].type==Tok!"EOF";}
	void popFront(){
		assert(!empty,"attempted to popFront empty lexer.");
		n = n+1 & buffer.length-1; s++;
		if(s<e) return; // if the buffer still contains elements
		assert(s==e && n==m);
		if(!numAnchors){// no anchors, that is easy, just reuse the whole buffer
			buffer[0]=buffer[n-1&buffer.length-1]; // we want at least one token of lookback, for nice error reporting
			e+=m=lexTo(buffer[n=1..$]);
			m=m+1&buffer.length-1;
			return;
		}
		assert(firstAnchor<buffer.length);
		size_t num;
		if(m < firstAnchor){ // there is an anchor but still space
			num=lexTo(buffer[n..firstAnchor]);
			e+=num; m=m+num&buffer.length-1;
			return;
		}else if(m > firstAnchor){ // ditto
			num=lexTo(buffer[m..$]);
			if(firstAnchor) num+=lexTo(buffer[0..firstAnchor]);
			e+=num; m=m+num&buffer.length-1;
			return;
		}
		auto len=buffer.length;
		buffer.length=len<<1; // double buffer size
		//buffer=(cast(Token*)realloc(buffer.ptr,(len<<1)*Token.sizeof))[0..len<<1];
		n=len+firstAnchor; // move start and firstAnchor
		buffer[len..n]=buffer[0..firstAnchor]; // move tokens to respect the new buffer topology
		num=0;
		if(n<buffer.length){
			num=lexTo(buffer[n..$]);
			e+=num; m=n+num&buffer.length-1;
		}	
		if(!m&&firstAnchor){
			num=lexTo(buffer[0..firstAnchor]);
			e+=num; m=num&buffer.length-1;
		}
	}
	Anchor pushAnchor(){
		if(!numAnchors) firstAnchor=n;
		numAnchors++;
		return Anchor(s);
	}
	void popAnchor(Anchor anchor){
		numAnchors--;
		if(!numAnchors) firstAnchor=size_t.max;
		n=n+anchor.index-s&buffer.length-1;
		s=anchor.index;
	}

private:
	Token tokError(string s, string rep, int l=0){
		auto r = token!"Error";
		r.str = s;
		r.loc = Location(rep, l?l:line);
		return r;
	}

	size_t lexTo(Token[] res)in{assert(res.length);}body{
		alias mallocAppender appender;
		if(!code.length) return 0;
		auto p=code.ptr;
		auto s=p;    // used if the input has to be sliced
		auto sl=line;// ditto
		char del;    // used if a delimiter of some sort needs to be remembered
		size_t len;  // used as a temporary that stores the length of the last UTF sequence
		size_t num=0;// number of tokens lexed, return value
		typeof(p) invCharSeq_l=null;
		void invCharSeq(){
			if(p>invCharSeq_l+1) errors~=tokError("unsupported character",p[0..1]);
			else errors[$-1].loc.rep=errors[$-1].loc.rep.ptr[0..errors[$-1].loc.rep.length+1];
			invCharSeq_l=p; p++;
		}
		// text macros:
		enum skipUnicode = q{if(*p<0x80){p++;break;} len=0; try utf.decode(p[0..4],len), p+=len; catch{invCharSeq();}};
		enum skipUnicodeCont = q{if(*p<0x80){p++;continue;} len=0; try utf.decode(p[0..4],len), p+=len; catch{invCharSeq();}}; // don't break, continue
		enum caseNl = q{case '\r':  if(p[1]=='\n') p++; goto case; case '\n': line++; p++; continue;};
		loop: while(res.length) { // breaks on EOF or buffer full
			auto begin=p; // start of a token's representation
			auto sline=line;
			switch(*p++){
				// whitespace
				case 0, 0x1A:
					res[0].type = Tok!"EOF";
					res[0].loc.rep=p[0..1];
					res[0].loc.line = line; // TODO: Why is this necessary?
					res=res[1..$];
					num++;
					break loop;
				case ' ', '\t', '\v':
					continue;   // ignore whitespace
				case '\r': if(*p=='\n') p++; goto case;
				case '\n': line++;
					continue;

				// simple tokens
				mixin(caseSimpleToken());

				// slash is special
				case '/':
					switch(*p){
						case '=': res[0].type = Tok!"/="; p++;
							break;
						case '/': p++;
							// parse "expected" comments
							if(*p==' ') p++;
							bool isExp=true;
							foreach(char c;"expected:"){
								if(*p==c) p++;
								else{ isExp=false; break; }
							}
							auto cur=p;
							// end of parse "expected" comments
							while(((*p!='\n') & (*p!='\r')) & ((*p!=0) & (*p!=0x1A))) mixin(skipUnicodeCont);
							if(isExp){
								res[0].type = Tok!"expected";
								res[0].str = cur[0..p-cur];
								break;
							}else continue; // ignore comment
						case '*':
							s=p++-1;
							sl=line;
							consumecom2: for(;;){
								switch(*p){
									mixin(caseNl); // handle newlines
									case '*': p++; if(*p=='/'){p++; break consumecom2;} break;
									case 0, 0x1A: errors~=tokError("unterminated /* */ comment",s[0..p-s],sl); break consumecom2;
									default: mixin(skipUnicode);
								}
							}
							continue; // ignore comment
						case '+':
							int d=1;
							s=p++-1;
							sl=line;
							consumecom3: while(d){
								switch(*p){
									mixin(caseNl); // handle newlines
									case '+':  p++; if(*p=='/') d--, p++; break;
									case '/':  p++; if(*p=='+') d++, p++; break;
									case 0, 0x1A: errors~=tokError("unterminated /+ +/ comment",s[0..p-s],sl); break consumecom3;
									default: mixin(skipUnicode);
								}
							}
							continue; // ignore comment
						default: res[0].type = Tok!"/"; break;
					}
					break;
				// dot is special
				case '.':
					if('0' > *p || *p > '9'){
						if(*p != '.')      res[0].type = Tok!".";
						else if(*++p!='.') res[0].type = Tok!"..";
						else               res[0].type = Tok!"...", p++;
						break;
					}
					goto case;
				// numeric literals
				case '0': .. case '9':
					res[0] = lexNumber(--p);
					if(res[0].type == Tok!"Error") errors~=res[0], res[0].type=Tok!"__error";
					break;
				// character literals
				case '\'':
					s = p; sl = line;
					res[0].type = Tok!"' '";
					if(*p=='\\'){
						try p++, res[0].int64 = cast(ulong)readEscapeSeq(p);
						catch(EscapeSeqException e) if(e.msg) errors~=tokError(e.msg,e.loc); else invCharSeq();
					}else{
						try{
							len=0;
							res[0].int64 = utf.decode(p[0..4],len);
							p+=len;
						}catch{invCharSeq();}
					}
					if(*p!='\''){
						//while((*p!='\''||(p++,0)) && *p && *p!=0x1A) mixin(skipUnicodeCont);
						errors~=tokError("unterminated character constant",(s-1)[0..p-s+1],sl);
					}else p++;
					break;
				// string literals
				// WYSIWYG string/AWYSIWYG string
				case 'r':
					if(*p!='"') goto case 'R';
					p++; del='"';
					goto skipdel;
				case '`':
					del = '`'; skipdel:
					s = p; sl = line;
					readwysiwyg: for(;;){
						if(*p==del){p++; break;} 
						switch(*p){
							mixin(caseNl); // handle newlines
							case 0, 0x1A:
								errors~=tokError("unterminated string literal", (s-1)[0..1],sl);
								break readwysiwyg;
							default: mixin(skipUnicode);
						}
					}
					res[0].type = Tok!"``";
					res[0].str = s[0..p-s-1]; // reference to code
					goto lexstringsuffix;
				// token string
				case 'q':
					if(*p=='"') goto delimitedstring;
					if(*p!='{') goto case 'Q';
					p++; s = p; sl = line;
					del = 0;
					readtstring: for(int nest=1;;){ // TODO: implement more efficiently
						Token tt;
						code=code[p-code.ptr..$]; // update code to allow recursion
						lexTo((&tt)[0..1]);
						p=code.ptr;
						switch(tt.type){
							case Tok!"EOF":
								errors~=tokError("unterminated token string literal", (s-2)[0..1], sl);
								break readtstring;
							case Tok!"{":  nest++; break;
							case Tok!"}":  nest--; if(!nest) break readtstring; break;
							default: break;
						}
					}
					res[0].type = Tok!"``";
					res[0].str = s[0..p-s-1]; // reference to code
					goto lexstringsuffix;
					delimitedstring:
					res[0].type = Tok!"``";
					s=++p; sl=line;
					switch(*p){
						case 'a': .. case 'z':
						case 'A': .. case 'Z':
							for(;;){
								switch(*p){
									case '\r': if(p[1]=='\n') p++; goto case;
									case '\n': line++; break;
									case 0, 0x1A: break;
									case 'a': .. case 'z':
									case 'A': .. case 'Z':
									case '0': .. case '9':
										p++;
										continue;
									case 0x80: .. case 0xFF:
										len=0;
										try{auto ch=utf.decode(p[0..4],len);
											if(isAlphaEx(ch)){p+=len; continue;}
											break;
										}catch{invCharSeq(); break;}
									default: break;
								}
								break;
							}
							if(*p!='\n' && *p!='\r') errors~=tokError("heredoc identifier must be followed by a new line",p[0..1]);
							while(((*p!='\n') & (*p!='\r')) & ((*p!=0) & (*p!=0x1A))) mixin(skipUnicodeCont); // mere error handling
							auto ident=s[0..p-s];
							if(*p=='\r'){line++;p++;if(*p=='\n') p++;}
							else if(*p=='\n'){line++;p++;}
							s=p;
							readheredoc: while((*p!=0) & (*p!=0x1A)){ // always at start of new line here
								for(auto ip=ident.ptr, end=ident.ptr+ident.length;;){
									if(ip==end) break readheredoc;
									switch(*p){
										mixin(caseNl);
										case 0x80: .. case 0xFF:
											len=0;
											try{auto ch=utf.decode(p[0..4],len);
												if(isAlphaEx(ch)){
													if(p[0..len]!=ip[0..len]) break;
													p+=len; ip+=len; continue;
												}
												break;
											}catch{invCharSeq(); break;}
										default: 
											if(*p!=*ip) break;
											p++; ip++; continue;
									}
									break;
								}
								while(((*p!='\n') & (*p!='\r')) & ((*p!=0) & (*p!=0x1A))) mixin(skipUnicodeCont);
								if(*p=='\r'){line++;p++;if(*p=='\n') p++;}
								else if(*p=='\n'){line++;p++;}
							}
							res[0].str = p>s+ident.length?s[0..p-s-ident.length]:""; // reference to code
							if(*p!='"') errors~=tokError("unterminated heredoc string literal",(s-1)[0..1],sl);
							else p++;
							break;
						default:
							del=*p; char rdel=del; dchar ddel=0;
							switch(del){
								case '[': rdel=']'; s=++p; break;
								case '(': rdel=')'; s=++p; break;
								case '<': rdel='>'; s=++p; break;
								case '{': rdel='}'; s=++p; break;
								case '\r': if(p[1]=='\n') p++; goto case;
								case '\n': line++; p++; goto case;
								case ' ','\t','\v':
									errors~=tokError("string delimiter cannot be whitespace",p[0..1]);
									goto case;
								case 0x80: case 0xFF:
									s=p;
									len=0;
									try{
										ddel=utf.decode(p[0..4],len);
										s=p+=len;
									}catch{invCharSeq();}
								default: p++; break;
							}
							if(ddel){
								while((*p!=0) & (*p!=0x1A)){
									if(*p=='\r'){line++;p++;if(*p=='\n') p++;}
									else if(*p=='\n'){line++;p++;}
									else if(*p<0x80){p++; continue;}
									try{
										auto x=utf.decode(p[0..4],len);
										if(ddel==x){
											res[0].str = s[0..p-s]; // reference to code
											p+=len; break;
										}
										p+=len;
									}catch{invCharSeq();}								
								}
							}else{
								for(int nest=1;(nest!=0) & (*p!=0) & (*p!=0x1A);){
									if(*p=='\r'){line++;p++;if(*p=='\n') p++;}
									else if(*p=='\n'){line++;p++;}
									else if(*p==rdel){nest--; p++;}
									else if(*p==del){nest++; p++;}
									else if(*p & 0x80){
										try{
											utf.decode(p[0..4],len);
											p+=len;
										}catch{invCharSeq();}
									}else p++;
								}
								res[0].str = s[0..p-s-1]; // reference to code
							}
							if(*p!='"'){
								if(*p) errors~=tokError("expected '\"' to close delimited string literal",p[0..1]);
								else errors~=tokError("unterminated delimited string literal",(s-2)[0..1],sl);
							}else p++;
							break;
					}
					goto lexstringsuffix;
				// Hex string
				case 'x':
					if(*p!='"') goto case 'X';
					auto r=appender!string(); p++; s=p; sl=line;
					readhexstring: for(int c=0,ch,d;;p++,c++){
						switch(*p){
							mixin(caseNl); // handle newlines
							case ' ', '\t', '\v': c--; break;
							case 0, 0x1A:
								errors~=tokError("unterminated hex string literal",(s-1)[0..1],sl);
								break readhexstring;
							case '0': .. case '9': d=*p-'0'; goto handlexchar;
							case 'a': .. case 'f': d=*p-('a'-0xa); goto handlexchar;
							case 'A': .. case 'F': d=*p-('A'-0xA); goto handlexchar;
							handlexchar:
								if(c&1) r.put(cast(char)(ch|d));
								else ch=d<<4; break;
							case '"':
								if(c&1) errors~=tokError(format("found %s character%s when expecting an even number of hex digits",toEngNum(c),c!=1?"s":""),s[0..p-s]);
								p++; break readhexstring;
							default:
								if(*p<128) errors~=tokError(format("found '%s' when expecting hex digit",*p),p[0..1]);
								else{
									s=p;
									len=0;
									try{
										auto chr = utf.decode(p[0..4],len);
										p+=len-1;
										if(isWhite(chr)) break; //TODO: newlines
									}catch{invCharSeq();}
									errors~=tokError(format("found '%s' when expecting hex digit",s[0..len]),s[0..len]);
								}
								break;
						}
					}
					res[0].type = Tok!"``";
					res[0].str = r.data;
					goto lexstringsuffix;
				// DQString
				case '"':{
					// appender only used if there is an escape sequence, slice otherwise
					// TODO: how costly is eager initialization?
					auto r=appender!string();
					auto start = s = p;
					readdqstring: for(;;){
						switch(*p){
							mixin(caseNl);
							case 0, 0x1A:
								errors~=tokError("unterminated string literal",(start-1)[0..1]);
								break readdqstring;
							case '\\':
								r.put(s[0..p++-s]);
								try r.put(readEscapeSeq(p));
								catch(EscapeSeqException e) if(e.msg) errors~=tokError(e.msg,e.loc); else invCharSeq();
								s = p;
								continue;
							case '"': p++; break readdqstring;
							default: mixin(skipUnicode);
						}
					}					
					res[0].type = Tok!"``";
					if(!r.data.length) res[0].str = start[0..p-1-start];
					else{ r.put(s[0..p-1-s]); res[0].str = r.data; }
					goto lexstringsuffix; }
					lexstringsuffix:
					if(*p=='c')      res[0].type = Tok!"``c", p++;
					else if(*p=='w') res[0].type = Tok!"``w", p++;
					else if(*p=='d') res[0].type = Tok!"``d", p++;
					break;
				// identifiers and keywords
				case '_':
				case 'a': .. case 'p': /*q, r*/ case 's': .. case 'w': /*x*/ case 'y', 'z':
				case 'A': .. case 'Z':
					s = p-1;
					identifier:
					readident: for(;;){
						switch(*p){
							case '_':
							case 'a': .. case 'z':
							case 'A': .. case 'Z':
							case '0': .. case '9':
								p++;
								break;
							case 0x80: .. case 0xFF:
								len=0;
								try if(isAlphaEx(utf.decode(p[0..4],len))) p+=len;
									else break readident;
								catch{break readident;} // will be caught in the next iteration
								break;
							default: break readident;
						}
					}
					
					res[0].name = s[0..p-s];
					res[0].type=isKeyword(res[0].name);
					break;
				case 0x80: .. case 0xFF:
					len=0; p--;
					try{auto ch=utf.decode(p[0..4],len);
						s=p, p+=len;
						if(isAlphaEx(ch)) goto identifier;
						if(!isWhite(ch)) errors~=tokError(format("unsupported character '%s'",ch),s[0..len]);
						// else if(isNewLine(ch)) line++; // TODO: implement this everywhere
						continue;
					}catch{} goto default;
				default:
					p--; invCharSeq(); p++;
					continue;
			}
			res[0].loc.rep=begin[0..p-begin];
			res[0].loc.line=sline;
			res=res[1..$];
			num++;
		}
		code=code[p-code.ptr..$];
		return num;
	}
	
	private Token lexNumber(ref immutable(char)* p){
		auto s=p;
		while('0'<=*p && *p<='9') p++;
		if(*p=='.'){ p++; while('0'<=*p && *p<='9') p++; }
		Token r;
		r.type=Tok!"0";
		r.str=s[0..p-s];
		return r;
	}
}

// Exception thrown on unrecognized escape sequences
private class EscapeSeqException: Exception{string loc; this(string msg,string loc){this.loc=loc;super(msg);}}

/* Reads an escape sequence and increases the given pointer to point past the sequence
	returns a dchar representing the read escape sequence or
	throws EscapeSeqException if the input is not well formed
 */
private dchar readEscapeSeq(ref immutable(char)* _p) in{assert(*(_p-1)=='\\');}body{ // pure
	auto p=_p;
	switch(*p){
		case '\'','\?','"','\\':
		return _p=p+1, *p;
		case 'a': return _p=p+1, '\a';
		case 'b': return _p=p+1, '\b';
		case 'f': return _p=p+1, '\f';
		case 'n': return _p=p+1, '\n';
		case 'r': return _p=p+1, '\r';
		case 't': return _p=p+1, '\t';
		case 'v': return _p=p+1, '\v';
		case '0': .. case '7': // BUG: Actually works for all extended ASCII characters
			auto s=p;
			for(int r=*p++-'0', i=0;;i++, r=(r<<3)+*p++-'0')
				if(i>2||'0'>*p||*p>'7'){
					_p=p; if(r>255) throw new EscapeSeqException(format("escape sequence '\\%s' exceeds ubyte.max",s[0..p-s]),(s-1)[0..p-s+1]);
					return cast(dchar)r;
				}
		case 'x', 'u', 'U':
			auto s=p;
			int numh=*p=='x'?p++,2:*p++=='u'?4:8;
			int r;
			foreach(i,x;p[0..numh]){
				switch(x){
					case '0': .. case '9': r=r<<4 | x-'0'; break;
					case 'a': .. case 'f': r=r<<4 | x-('a'-0xa); break;
					case 'A': .. case 'F': r=r<<4 | x-('A'-0xA); break;
					default:
						_p=p;
						throw new EscapeSeqException(format("escape hex sequence has %s digit%s instead of %s",
						                                    toEngNum(cast(uint)i),(i!=1?"s":""),toEngNum(numh)),(_p-1)[0..p-_p+1]);
				}
				p++;
			}
			_p=p;
			if(!utf.isValidDchar(cast(dchar)r)) throw new EscapeSeqException(format("invalid UTF character '\\%s'",s[0..p-s]),(s-1)[0..p-s+1]);
			return cast(dchar)r;
		default:
			if(*p<128){_p=p+1; throw new EscapeSeqException(format("unrecognized escape sequence '\\%s'",*p),p[0..1]);}
			else{
				auto s=p;
				size_t len=0;
				try{
					utf.decode(p[0..4],len);
					p+=len;
				}catch{throw new EscapeSeqException(null,p[0..1]);}
				_p=p; throw new EscapeSeqException(format("unrecognized escape sequence '\\%s'",s[0..len]),s[0..len]);
			}
	}
}


unittest{
	alias token t;
	assert(lex(".\r..\v...\t  ....\r\n") == [t!".", t!"\n", t!"..", t!"...", t!"...", t!".",t!"\n"]);
	assert(to!string(lex(ulong.max.stringof)[0]) == ulong.max.stringof);
	assert(lex(ulong.max.stringof[0..$-2])[0].type == Tok!"Error");
	foreach(i;0..1000UL){
		ulong v = i^^4*1337;
		ulong w = lex(to!string(v))[0].int64;
		assert(w == v);
	}
	// 184467440737095516153.6L is rounded to 184467440737095516160.0L
	assert(lex("184467440737095516153.6L")[0].flt80 == 184467440737095516153.6L);//184467440737095516160.0L);
	assert(lex("0x1234_5678_9ABC_5A5AL")[0].int64 == 0x1234_5678_9ABC_5A5AL);
}

private string isKw(string[] cases){
	string r="switch(s){";
	foreach(x;cases) r~=`case "`~x~`": return Tok!"`~x~`";`;
	return r~="default: break;}";
}
TokenType isKeyword(string s){
	switch(s.length){
		case 2:
			if(s=="if") return Tok!"if";
			break;
		case 3:
			if(s=="def") return Tok!"def";
			break;
		case 4:
			if(s=="true") return Tok!"true";
			if(s=="else") return Tok!"else";
			break;
		case 5:
			if(s=="false") return Tok!"false";
		case 6:
			if(s=="assert") return Tok!"assert";
			if(s=="return") return Tok!"return";
			if(s=="repeat") return Tok!"repeat";
		case 7:
			if(s=="observe") return Tok!"observe";
		default: break;
	}
	return Tok!"i";
}









