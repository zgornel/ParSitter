# ParSitter

A small utility to parse code, files and directories with [tree-sitter](https://tree-sitter.github.io/tree-sitter/)

[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md)
[![codecov](https://codecov.io/gh/zgornel/ParSitter/graph/badge.svg?token=GWKJKBZ5FB)](https://codecov.io/gh/zgornel/ParSitter)
[![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)

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

The library is still very experimental.
