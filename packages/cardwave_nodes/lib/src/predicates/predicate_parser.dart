import 'package:cardwave_nodes/src/predicates/predicate_ast.dart';
import 'package:cardwave_nodes/src/predicates/predicate_parse_exception.dart';

/// Parses a predicate expression string into an AST. Throws
/// [PredicateParseException] on malformed input.
PredicateNode parsePredicate(String source) {
  final tokens = _tokenize(source);
  final parser = _Parser(tokens);
  final result = parser._expression();
  if (parser._current.type != _TokenType.eof) {
    throw PredicateParseException(
      'Unexpected token "${parser._current.lexeme}"',
      parser._current.position,
    );
  }
  return result;
}

enum _TokenType {
  lparen,
  rparen,
  andOp,
  orOp,
  notOp,
  eq,
  ne,
  lt,
  le,
  gt,
  ge,
  number,
  string,
  boolLit,
  fieldRef,
  eof,
}

class _Token {
  const _Token(this.type, this.lexeme, this.position, [this.value]);
  final _TokenType type;
  final String lexeme;
  final int position;
  final Object? value;
}

const _keywords = <String, _TokenType>{
  'AND': _TokenType.andOp,
  'OR': _TokenType.orOp,
  'NOT': _TokenType.notOp,
  'true': _TokenType.boolLit,
  'false': _TokenType.boolLit,
};

List<_Token> _tokenize(String source) {
  final tokens = <_Token>[];
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    if (_isWhitespace(c)) {
      i++;
      continue;
    }
    if (c == '(') {
      tokens.add(_Token(_TokenType.lparen, '(', i));
      i++;
      continue;
    }
    if (c == ')') {
      tokens.add(_Token(_TokenType.rparen, ')', i));
      i++;
      continue;
    }
    if (c == '=' && _peek(source, i + 1) == '=') {
      tokens.add(_Token(_TokenType.eq, '==', i));
      i += 2;
      continue;
    }
    if (c == '!' && _peek(source, i + 1) == '=') {
      tokens.add(_Token(_TokenType.ne, '!=', i));
      i += 2;
      continue;
    }
    if (c == '<') {
      if (_peek(source, i + 1) == '=') {
        tokens.add(_Token(_TokenType.le, '<=', i));
        i += 2;
      } else {
        tokens.add(_Token(_TokenType.lt, '<', i));
        i++;
      }
      continue;
    }
    if (c == '>') {
      if (_peek(source, i + 1) == '=') {
        tokens.add(_Token(_TokenType.ge, '>=', i));
        i += 2;
      } else {
        tokens.add(_Token(_TokenType.gt, '>', i));
        i++;
      }
      continue;
    }
    if (c == '"') {
      final (lexeme, length) = _readString(source, i);
      tokens.add(_Token(_TokenType.string, lexeme, i, lexeme));
      i += length;
      continue;
    }
    if (_isDigit(c) ||
        (c == '.' &&
            _peek(source, i + 1) != null &&
            _isDigit(_peek(source, i + 1)!))) {
      final (lexeme, length) = _readNumber(source, i);
      tokens.add(_Token(_TokenType.number, lexeme, i, double.parse(lexeme)));
      i += length;
      continue;
    }
    if (_isIdentStart(c)) {
      final (lexeme, length) = _readIdent(source, i);
      final kw = _keywords[lexeme];
      if (kw != null) {
        tokens.add(_Token(
          kw,
          lexeme,
          i,
          kw == _TokenType.boolLit ? lexeme == 'true' : null,
        ));
      } else {
        tokens.add(_Token(_TokenType.fieldRef, lexeme, i, lexeme));
      }
      i += length;
      continue;
    }
    throw PredicateParseException('Unexpected character "$c"', i);
  }
  tokens.add(_Token(_TokenType.eof, '', source.length));
  return tokens;
}

bool _isWhitespace(String c) => c == ' ' || c == '\t' || c == '\n' || c == '\r';
bool _isDigit(String c) => c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;
bool _isIdentStart(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A) || c == '_';
}

bool _isIdentContinue(String c) =>
    _isIdentStart(c) || _isDigit(c) || c == '.';

String? _peek(String source, int i) =>
    i < source.length ? source[i] : null;

(String, int) _readString(String source, int start) {
  // start points at the opening quote
  var i = start + 1;
  final buf = StringBuffer();
  while (i < source.length && source[i] != '"') {
    buf.write(source[i]);
    i++;
  }
  if (i >= source.length) {
    throw PredicateParseException('Unterminated string literal', start);
  }
  return (buf.toString(), i - start + 1);
}

(String, int) _readNumber(String source, int start) {
  var i = start;
  var seenDot = false;
  while (i < source.length) {
    final c = source[i];
    if (_isDigit(c)) {
      i++;
    } else if (c == '.' && !seenDot) {
      seenDot = true;
      i++;
    } else {
      break;
    }
  }
  return (source.substring(start, i), i - start);
}

(String, int) _readIdent(String source, int start) {
  var i = start;
  while (i < source.length && _isIdentContinue(source[i])) {
    i++;
  }
  return (source.substring(start, i), i - start);
}

class _Parser {
  _Parser(this._tokens);
  final List<_Token> _tokens;
  int _pos = 0;

  // `_tokenize` always appends an EOF sentinel, so `_pos` never advances
  // past the last element while the parser is still running.
  // ignore: qcheck/avoid_unsafe_collection_methods
  _Token get _current => _tokens[_pos];

  bool _match(_TokenType type) {
    if (_current.type == type) {
      _pos++;
      return true;
    }
    return false;
  }

  void _expect(_TokenType type, String message) {
    if (!_match(type)) {
      throw PredicateParseException(message, _current.position);
    }
  }

  PredicateNode _expression() => _or();

  PredicateNode _or() {
    var left = _and();
    while (_match(_TokenType.orOp)) {
      left = OrNode(left, _and());
    }
    return left;
  }

  PredicateNode _and() {
    var left = _unary();
    while (_match(_TokenType.andOp)) {
      left = AndNode(left, _unary());
    }
    return left;
  }

  PredicateNode _unary() {
    if (_match(_TokenType.notOp)) {
      return NotNode(_unary());
    }
    return _comparisonOrAtom();
  }

  PredicateNode _comparisonOrAtom() {
    final left = _atom();
    final op = _comparisonOp();
    if (op == null) return left;
    return ComparisonNode(left, op, _atom());
  }

  ComparisonOp? _comparisonOp() {
    final op = switch (_current.type) {
      _TokenType.eq => ComparisonOp.eq,
      _TokenType.ne => ComparisonOp.ne,
      _TokenType.lt => ComparisonOp.lt,
      _TokenType.le => ComparisonOp.le,
      _TokenType.gt => ComparisonOp.gt,
      _TokenType.ge => ComparisonOp.ge,
      _TokenType.lparen ||
      _TokenType.rparen ||
      _TokenType.andOp ||
      _TokenType.orOp ||
      _TokenType.notOp ||
      _TokenType.number ||
      _TokenType.string ||
      _TokenType.boolLit ||
      _TokenType.fieldRef ||
      _TokenType.eof =>
        null,
    };
    if (op != null) _pos++;
    return op;
  }

  PredicateNode _atom() {
    if (_match(_TokenType.lparen)) {
      final inner = _expression();
      _expect(_TokenType.rparen, 'Expected ")"');
      return inner;
    }
    final tok = _current;
    switch (tok.type) {
      case _TokenType.number:
      case _TokenType.string:
      case _TokenType.boolLit:
        _pos++;
        return LiteralNode(tok.value!);
      case _TokenType.fieldRef:
        _pos++;
        return FieldRefNode(tok.value! as String);
      case _TokenType.lparen:
      case _TokenType.rparen:
      case _TokenType.andOp:
      case _TokenType.orOp:
      case _TokenType.notOp:
      case _TokenType.eq:
      case _TokenType.ne:
      case _TokenType.lt:
      case _TokenType.le:
      case _TokenType.gt:
      case _TokenType.ge:
      case _TokenType.eof:
        throw PredicateParseException(
          'Expected a literal, field reference, or "("; got "${tok.lexeme}"',
          tok.position,
        );
    }
  }
}
