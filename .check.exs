# SPDX-FileCopyrightText: 2025 James Harton
#
# SPDX-License-Identifier: MIT

[
  tools: [
    {:sobelow, "mix sobelow -i Config.HTTPS --exit"},
    {:spark_formatter, "mix spark.formatter --check"},
    {:spark_cheat_sheets, "mix spark.cheat_sheets --check"},
    {:reuse, command: ["pipx", "run", "reuse", "lint", "-q"]}
  ]
]
