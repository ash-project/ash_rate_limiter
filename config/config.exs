import Config

config :ash,
  allow_forbidden_field_for_relationships_by_default?: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false]

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :actions,
        :aggregates,
        :attributes,
        :calculations,
        :changes,
        :code_interface,
        :ets,
        :identities,
        :multitenancy,
        :policies,
        :postgres,
        :preparations,
        :pub_sub,
        :relationships,
        :resource,
        :validations
      ]
    ],
    "Ash.Domain": [
      section_order: [
        :authorization,
        :domain,
        :execution,
        :mix_tasks,
        :policies,
        :resources
      ]
    ]
  ]

if Mix.env() in [:dev, :test] do
  config :git_ops,
    mix_project: Mix.Project.get!(),
    types: [types: [tidbit: [hidden?: true], important: [header: "Important Changes"]]],
    version_tag_prefix: "v",
    manage_mix_version?: true,
    manage_readme_version: true

  config :ash_rate_limiter, ash_domains: [Example]
end

if Mix.env() == :test do
  config :logger, level: :warning
  config :ash, disable_async?: true
end
