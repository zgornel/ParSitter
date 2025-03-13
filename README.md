# ParSitter

A small utility to parse code, files and directories with [tree-sitter](https://tree-sitter.github.io/tree-sitter/)

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
