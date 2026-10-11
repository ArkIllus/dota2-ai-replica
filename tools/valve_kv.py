"""Lossless-order Valve KeyValues 1 reader (not KV3).

Preserves duplicate keys, source lines, directives and unevaluated conditions.
No #base include loading, platform evaluation or engine default inference.
"""
from dataclasses import dataclass, field


class KVError(ValueError):
    pass


@dataclass
class Token:
    text: str
    line: int
    kind: str = "text"


@dataclass
class Entry:
    key: str
    value: object
    line: int
    conditions: list = field(default_factory=list)


@dataclass
class Node:
    entries: list = field(default_factory=list)

    def all(self, key):
        return [entry for entry in self.entries if entry.key == key]

    def one(self, key):
        matches = self.all(key)
        if len(matches) != 1:
            raise KVError(f"Expected exactly one {key!r}, found {len(matches)}")
        return matches[0]


def tokenize(text):
    i, line, size = 0, 1, len(text)
    while i < size:
        char = text[i]
        if char.isspace() or char == '\ufeff':
            line += char == '\n'
            i += 1
            continue
        if text.startswith('//', i):
            end = text.find('\n', i)
            i = size if end < 0 else end
            continue
        if text.startswith('/*', i):
            start, depth = line, 1
            i += 2
            while i < size and depth:
                if text.startswith('/*', i):
                    depth += 1
                    i += 2
                elif text.startswith('*/', i):
                    depth -= 1
                    i += 2
                else:
                    line += text[i] == '\n'
                    i += 1
            if depth:
                raise KVError(f"Unterminated block comment at line {start}")
            continue
        if char in '{}':
            yield Token(char, line, char)
            i += 1
            continue
        if char == '[':
            start = i
            end = text.find(']', i + 1)
            if end < 0:
                raise KVError(f"Unterminated condition at line {line}")
            yield Token(text[start:end+1], line, 'condition')
            line += text[start:end+1].count('\n')
            i = end + 1
            continue
        if char == '"':
            start, buf = line, []
            i += 1
            while i < size and text[i] != '"':
                if text[i] == '\\' and i + 1 < size:
                    nxt = text[i + 1]
                    escapes = {'"': '"', '\\': '\\', 'n': '\n', 'r': '\r', 't': '\t'}
                    buf.append(escapes.get(nxt, '\\' + nxt))
                    i += 2
                else:
                    line += text[i] == '\n'
                    buf.append(text[i])
                    i += 1
            if i >= size:
                raise KVError(f"Unterminated quoted string at line {start}")
            yield Token(''.join(buf), start)
            i += 1
            continue
        start = i
        while i < size and not text[i].isspace() and text[i] not in '{}"[':
            if text.startswith('//', i) or text.startswith('/*', i):
                break
            i += 1
        if i == start:
            raise KVError(f"Unexpected character {text[i]!r} at line {line}")
        yield Token(text[start:i], line)


def parse(text):
    tokens, cursor = list(tokenize(text)), 0

    def block(nested=False):
        nonlocal cursor
        node = Node()
        while cursor < len(tokens):
            key = tokens[cursor]
            if key.kind == '}':
                if not nested:
                    raise KVError(f"Unexpected closing brace at line {key.line}")
                cursor += 1
                return node
            if key.kind != 'text':
                raise KVError(f"Expected key at line {key.line}")
            cursor += 1
            if cursor >= len(tokens):
                raise KVError(f"Missing value for {key.text!r} at line {key.line}")
            token = tokens[cursor]
            cursor += 1
            if token.kind == '{':
                value = block(True)
            elif token.kind == 'text':
                value = token.text
            else:
                raise KVError(f"Invalid value for {key.text!r} at line {token.line}")
            conditions = []
            while cursor < len(tokens) and tokens[cursor].kind == 'condition':
                conditions.append(tokens[cursor].text)
                cursor += 1
            node.entries.append(Entry(key.text, value, key.line, conditions))
        if nested:
            raise KVError('Missing closing brace at end of input')
        return node

    return block()


def pairs(node):
    return [{"key": e.key, "value": pairs(e.value) if isinstance(e.value, Node) else e.value,
             "line": e.line, "conditions": e.conditions} for e in node.entries]


def plain(node):
    """Convenience view; repeated keys become lists. pairs() is authoritative."""
    result = {}
    for key in dict.fromkeys(e.key for e in node.entries):
        values = [plain(e.value) if isinstance(e.value, Node) else e.value for e in node.all(key)]
        result[key] = values[0] if len(values) == 1 else values
    return result
