import osproc, os, parseopt, strformat, strutils

const
  Version = "0.0.1"
  Usage = fmt"""
nim_expander - expander for competitive programing library {Version}
Usage:
  nim_expander [options] nimfile
Options:
  -o, --out:file        set the output file (default: stdout)
  -m, --modules         add the module dirctory to expand (default: .)
  --version             show the version
  --help                show this help
"""

proc writeHelp() =
  stdout.write(Usage)
  stdout.flushFile()
  quit(0)

proc writeVersion() =
  stdout.write(Version & "\n")
  stdout.flushFile()
  quit(0)

proc getDepsFilePath(source: string): string =
  result = getTempDir() / lastPathPart(source).changeFileExt("deps")

proc genDeps(source: string) =
  let fullpath = absolutePath(source)
  discard execProcess(fmt"nim cpp --genScript:on {fullpath}", workingdir = getTempDir())

proc readDeps(depsFilePath: string): string =
  let f = open(depsFilePath, FileMode.fmRead)
  result = f.readAll()
  f.close()

type ModulePathInfo = tuple
  fullPath: string
  relPath: string

proc getExpand(deps: seq[string], bases: seq[string]): seq[ModulePathInfo] =
  for dep in deps:
    for base in bases:
      if dep.startsWith(base):
        result.add((fullPath: dep, relPath: dep.relativePath(base)))

proc readCode(path: string): string =
  stderr.writeLine(fmt"expand: {path}")
  var f = open(path, FileMode.fmRead)
  result = f.readAll()
  f.close()

const
  expandHeader = """
static:
  when not defined(lazyCompile):
    template writeModule(path: string, code: untyped): untyped =
      discard staticExec("mkdir -p $(dirname " & path & ")")
      discard staticExec("cat - > " & path, astToStr(code))
"""
  expandFooter = """
    type CompileError = object of CatchableError
    let resp = gorgeEx("nim cpp -d:lazyCompile -p:. -d:release --opt:speed --multimethods:on --warning[SmallLshouldNotBeUsed]:off --hints:off --out:a.out Main.nim")
    if resp.exitCode != 0:
      raise newException(CompileError, resp.output)
    quit(resp.exitCode)
"""

proc expand*(source: string, bases: seq[string]): string =
  let depsFilePath = getDepsFilePath(source)

  genDeps(source)
  assert fileExists(depsFilePath)

  let deps = readDeps(depsFilePath).splitLines()
  removeFile(depsFilePath)

  let expandModules = getExpand(deps, bases)

  var res = newSeq[string]()
  if expandModules.len != 0:
    res.add(expandHeader)

    for module in expandModules:
      var innerTripleQuote = false
      res.add("    writeModule(\"" & module.relPath & "\"):")
      for line in readCode(module.fullPath).splitLines():
        if innerTripleQuote:
          res.add(line)
        else:
          res.add("      " & line)
        if line.count("\"\"\"") mod 2 == 1:
          innerTripleQuote = not innerTripleQuote

      res.add("")

    res.add(expandFooter)

  res.add(readCode(source))
  result = res.join("\n")

proc resolvePath(path: string): string =
  result = path.expandTilde().normalizedPath().absolutePath()

proc main() =
  var
    filename, outfile: string
    modules = newSeq[string]()

  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      filename = key
    of cmdLongOption, cmdShortOption:
      case normalize(key)
      of "o", "out": outfile = val
      of "m", "modules": modules.add(resolvePath(val))
      of "help", "h": writeHelp()
      of "version", "v": writeVersion()
      else: writeHelp()
    of cmdEnd: assert(false) # cannot happen

  if filename.len == 0:
    quit "[Error] no input file."

  let res = expand(filename, modules)

  if outfile.len == 0:
    stdout.write(res)
    stdout.flushFile()
  else:
    var ofs = outfile.open(FileMode.fmWrite)
    ofs.write(res)
    ofs.close()

when isMainModule:
  main()
