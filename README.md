# ParSitter

A small utility to parse code, files and directories with [tree-sitter](https://tree-sitter.github.io/tree-sitter/)

## Running
For example, to parse source code,
```
$ julia parsitter.jl 'def foo():pass' --input-type code --language python --log-level debug
```

or, for files
```
$ julia parsitter.jl my_file.py --input-type code --language python --log-level debug
```
and for directories
```
$ julia parsitter.jl ~/projects/tmp/FluentPython --input-type directory --language python --log-level debug
```

The library is still very experimental.
