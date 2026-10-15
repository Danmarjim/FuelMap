#!/usr/bin/env bash
# Hook PostToolUse: autocorrige con SwiftLint el fichero .swift que el agente acaba de editar
# y, si quedan violaciones, se las devuelve (exit 2) para que las arregle en el mismo turno.

INPUT="$(cat)"
FILE="$(printf '%s' "$INPUT" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)"

[[ "$FILE" == *.swift ]] || exit 0
[[ -f "$FILE" ]] || exit 0
command -v swiftlint >/dev/null 2>&1 || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

swiftlint lint --fix --quiet "$FILE" >/dev/null 2>&1 || true
OUTPUT="$(swiftlint lint --quiet --strict "$FILE" 2>/dev/null)"

if [[ -n "$OUTPUT" ]]; then
  {
    echo "SwiftLint ha encontrado problemas en $FILE que no ha podido corregir solo:"
    echo "$OUTPUT"
  } >&2
  exit 2
fi

exit 0
