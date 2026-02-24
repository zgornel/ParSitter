# ParSitter

A wrapper around [tree-sitter](https://tree-sitter.github.io/tree-sitter/) written in Julia. It allows for easy parsing and querying of code ASTs.

[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md)
[![Tests](https://github.com/zgornel/ParSitter/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/zgornel/ParSitter/actions/workflows/test.yml?query=branch%3Amaster)
[![codecov](https://codecov.io/gh/zgornel/ParSitter/graph/badge.svg?token=GWKJKBZ5FB)](https://codecov.io/gh/zgornel/ParSitter)
[![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://zgornel.github.io/ParSitter/dev)

## Parsing
### Files
```
$ julia parsitter.jl my_file.py --input-type code --language python --log-level debug
```
### Directories
```
$ julia parsitter.jl ~/projects/tmp/FluentPython --input-type directory --language python --log-level debug
```
### Inline code

This works,
```
$ julia parsitter.jl 'def foo():pass' --input-type code --language python --log-level debug
```
If escape chars are present, use the `--escape-chars` option:
```
$ julia parsitter.jl 'def foo():\n\tpass' --input-type code --escape-chars --language python --log-level debug
```
## Differences from TreeSitter.jl
This package differs from [TreeSitter.jl](https://github.com/MichaelHatherly/TreeSitter.jl) in that it calls the tree-sitter parsing cli externally and reads directly the XML result. TreeSitter.jl provides a much tighter integration with tree-sitter parsers and the querying mechanisms. ParSitter provides a looser coupling with tree-sitter and a more flexible querying API.

## License

This code has an MIT license and therefore it is free.


## Reporting Bugs

Please [file an issue](https://github.com/zgornel/ParSitter/issues/new) to report a bug or request a feature.


## References

[1] https://tree-sitter.github.io/tree-sitter/

[2] https://en.wikipedia.org/wiki/Abstract_syntax_tree
