import std/[osproc, os, parseopt, strformat, strutils, tempfiles, sequtils]

const
  Version = "0.0.2"

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

  ExpandHeader = """
static:
  when not defined(lazyCompile):
    template writeModule(path: string, code: untyped): untyped =
      discard staticExec("mkdir -p $(dirname " & path & ")")
      discard staticExec("cat - > " & path, astToStr(code))
"""

  ExpandFooter = """
    type CompileError = object of CatchableError
    let resp = gorgeEx("nim cpp -d:lazyCompile -p:. -d:release --opt:speed --multimethods:on --warning[SmallLshouldNotBeUsed]:off --hints:off --out:a.out Main.nim")
    if resp.exitCode != 0:
      raise newException(CompileError, resp.output)
    quit(resp.exitCode)
"""


proc writeHelp() =
  stdout.write(Usage)
  stdout.flushFile()
  quit(0)


proc writeVersion() =
  stdout.write(Version & "\n")
  stdout.flushFile()
  quit(0)


type ModulePathInfo = tuple
  fullPath: string
  relPath: string


proc readFile(path: string): string =
  stderr.writeLine(fmt"read: {path}")
  var f = open(path, FileMode.fmRead)
  result = f.readAll()
  f.close()


proc getExpand(deps: seq[string], bases: seq[string]): seq[ModulePathInfo] =
  ## 依存するファイル一覧からコマンドラインで指定されたパスの下にあるものを抽出する。
  for dep in deps:
    for base in bases:
      if dep.startsWith(base):
        result.add((fullPath: dep, relPath: dep.relativePath(base)))


proc genDeps(source: string): seq[string] =
  ## --genScript:onをつけてコンパイルすると、依存するファイル一覧.depsが生成される
  let
    tempDir = createTempDir("nim_expander", "")
    depsFile = tempDir / lastPathPart(source).changeFileExt("deps")

  try:
    let (_, exitCode) = execCmdEx(fmt"nim cpp --genScript:on {source.absolutePath()}", workingdir = tempDir)
    if exitCode != 0:
      stderr.write("Failed to analyze dependency.\n")
      stderr.flushFile()
      quit(1)
    assert depsFile.fileExists()
    return depsFile.readFile().splitLines()

  finally:
    tempDir.removeDir()

proc resolvePathOrModle(dirPathOrModule: string): string =
  ## ローカルパス->モジュールの順で解決

  let asAbsolutePath = dirPathOrModule.expandTilde.absolutePath.normalizedPath
  if asAbsolutePath.dirExists or asAbsolutePath.fileExists:
    return asAbsolutePath

  ## nimble pathコマンドでパス取得
  let (output, exitCode) = execCmdEx(fmt"nimble path {dirPathOrModule}")
  if exitCode == 0:
    return output.strip

  quit fmt"Failed to resolve: {dirPathOrModule}"


proc expand*(source: string, modulesOrPaths: seq[string]): string =
  let
    expandTarget = modulesOrPaths.map(resolvePathOrModle) # ソースが依存していた場合展開するファイルの一覧
    deps = genDeps(source)
    expandModules = getExpand(deps, expandTarget)         # 実際に展開してソースに埋め込むファイルの一覧

  var res = newSeq[string]()
  if expandModules.len != 0:
    res.add(ExpandHeader)

    for module in expandModules:
      var innerTripleQuote = false
      res.add("    writeModule(\"" & module.relPath & "\"):")
      for line in readFile(module.fullPath).splitLines():
        if innerTripleQuote:
          res.add(line)
        else:
          res.add("      " & line)
        if line.count("\"\"\"") mod 2 == 1:
          innerTripleQuote = not innerTripleQuote

      res.add("")

    res.add(ExpandFooter)

  res.add(readFile(source))
  result = res.join("\n")


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
      of "m", "modules": modules.add(val)
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
