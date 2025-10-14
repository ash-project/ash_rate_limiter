# SPDX-FileCopyrightText: 2025 James Harton
#
# SPDX-License-Identifier: MIT

spark_locals_without_parens = [
  action: 1,
  action: 2,
  description: 1,
  hammer: 1,
  key: 1,
  limit: 1,
  per: 1
]

[
  inputs: ["{mix,.formatter,.check}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  plugins: [Spark.Formatter],
  import_deps: [:ash, :ash_rate_limiter],
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
