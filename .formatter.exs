spark_locals_without_parens = [
  action: 1,
  description: 1,
  hammer: 1,
  key: 1,
  limit: 0,
  limit: 1,
  scale: 1
]

[
  inputs: ["{mix,.formatter,.check}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  plugins: [Spark.Formatter],
  import_deps: [:ash],
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
