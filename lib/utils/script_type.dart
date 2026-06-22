enum ScriptType {
  debug("--debug"),
  release("--release"),
  help("--help"),
  fix("--fix"),
  none("");

  final String type;
  const ScriptType(this.type);
}

extension Scripts on List<String> {
  ScriptType get runner {
    if (contains(ScriptType.debug.type)) return ScriptType.debug;
    if (contains(ScriptType.help.type)) return ScriptType.help;
    if (contains(ScriptType.release.type)) return ScriptType.release;
    if (contains(ScriptType.fix.type)) return ScriptType.fix;
    return ScriptType.none;
  }
}
