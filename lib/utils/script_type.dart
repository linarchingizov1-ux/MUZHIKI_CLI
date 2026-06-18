enum ScriptType {
  debug("--debug"),
  release("--release"),
  help("--help"),
  none("");

  final String type;
  const ScriptType(this.type);
}

extension Scripts on List<String> {
  ScriptType get runner {
    if (contains(ScriptType.debug.type)) return ScriptType.debug;
    if (contains(ScriptType.help.type)) return ScriptType.help;
    if (contains(ScriptType.release.type)) return ScriptType.release;
    return ScriptType.none;
  }
}
