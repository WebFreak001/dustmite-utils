import dparse.ast;
import dparse.lexer;
import dparse.parser;
import dparse.rollback_allocator;
import std.algorithm;
import std.array;
import std.file;
import std.functional;
import std.stdio;
import std.traits;

void showHelp(string progName)
{
	writeln("Usage:");
	writeln("  ", progName, " clear-unittests [SOURCES...]");
	writeln("  ", progName, " remove-comments [SOURCES...]");
}

void main(string[] args)
{
	// support sym-linked shortcuts
	if (args[0].endsWith("clear-unittests"))
		args = args[0] ~ "clear-unittests" ~ args[1 .. $];
	else if (args[0].endsWith("remove-comments"))
		args = args[0] ~ "remove-comments" ~ args[1 .. $];

	if (args.length == 1)
	{
		showHelp(args[0]);
		return;
	}

	switch (args[1])
	{
	case "remove-comments":
		runOnSources(args[2 .. $], (tokens) => tokens.map!removeComments.array);
		break;
	case "clear-unittests":
		runOnSources(args[2 .. $], toDelegate(&clearUnittests));
		break;
	default:
		showHelp(args[0]);
		break;
	}
}

void runOnSources(string[] args, const(Token)[] delegate(const(Token)[]) callback)
{
	auto collected = appender!(string[]);

	bool includeAll = false;
	foreach (arg; args)
	{
		if (arg == "--")
			includeAll = true;
		else if (includeAll || !arg.startsWith("-"))
		{
			if (isFile(arg))
			{
				collected ~= arg;
			}
			else if (exists(arg))
			{
				foreach (file; dirEntries(arg, SpanMode.breadth))
					if (file.isFile)
						collected ~= file;
			}
			else
				throw new Exception("Input source " ~ arg ~ " not found!");
		}
	}

	StringCache cache = StringCache(StringCache.defaultBucketCount);
	foreach (file; collected.data)
	{
		if (!file.endsWith(".d", ".di"))
			continue;

		LexerConfig config = LexerConfig(file, StringBehavior.source, WhitespaceBehavior.include, CommentBehavior.noIntern);
		auto code = readText(file);
		auto tokens = getTokensForParser(code, config, &cache);
		auto newTokens = callback(tokens);

		string newCode = newTokens.map!reconstructTokenCode.join;
		if (code != newCode)
		{
			writeln("REWRITE ", file);
			std.file.write(file, newCode);
		}
	}
}

string reconstructTokenCode(const Token token)
{
	string ret;
	foreach (leading; token.leadingTrivia)
		ret ~= leading.text;
	if (token.text.length)
		ret ~= token.text;
	else
		ret ~= str(token.type);
	foreach (trailing; token.trailingTrivia)
		ret ~= trailing.text;
	return ret;
}

const(Token) removeComments(const(Token) token)
{
	Token impl()
	{
		Token ret;
		ret.text = token.text;
		ret.line = token.line;
		ret.column = token.column;
		ret.index = token.index;
		ret.type = token.type;
		foreach (leading; token.leadingTrivia)
			if (leading.type != tok!"comment")
				ret.leadingTrivia ~= leading;
		foreach (trailing; token.trailingTrivia)
			if (trailing.type != tok!"comment")
				ret.trailingTrivia ~= trailing;
		return ret;
	}

	foreach (leading; token.leadingTrivia)
		if (leading.type == tok!"comment")
			return impl();
	foreach (trailing; token.trailingTrivia)
		if (trailing.type == tok!"comment")
			return impl();
	return token;
}

const(Token)[] clearUnittests(const(Token)[] tokens)
{
	ptrdiff_t[2][] ranges;
	ptrdiff_t i = 0;
	while (i < tokens.length)
	{
		auto newIndex = tokens[i .. $].countUntil!(a => a.type == tok!"unittest");
		if (newIndex == -1)
			break;
		i += newIndex;
		if (!(i + 1 < tokens.length && tokens[i + 1] == tok!"{"))
		{
			i++;
			continue;
		}

		auto end = countUntilBalancedPair!(tok!"{", tok!"}")(tokens, i + 1);
		if (end == -1)
		{
			writeln("Warning: unclosed unittest");
			break;
		}

		ranges ~= [i + 2, end - 1];
		i = end + 1;
	}

	foreach_reverse (range; ranges)
		tokens = tokens[0 .. range[0]] ~ tokens[range[1] .. $];

	return tokens;
}

ptrdiff_t countUntilBalancedPair(alias opening, alias closing, T)(scope const(T)[] tokens, ptrdiff_t start, int startingDepth = 0)
{
	alias depth = startingDepth;
	do
	{
		if (start == tokens.length)
			return -1;

		if (tokens[start] == opening)
			depth++;
		else if (tokens[start] == closing)
			depth--;
		start++;
	}
	while (depth != 0);
	return start;
}

unittest
{
	int[] arr = [40, 41, 1, 42, 43, 44, 1, 2, 45, 2, 46, 47, 48];
	assert(arr.countUntilBalancedPair!(1, 2)(2) == 10); // index is AFTER the closing type
}
