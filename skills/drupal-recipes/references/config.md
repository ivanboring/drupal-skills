# Configuration and inputs

Read the installed [ConfigConfigurator](../../../../web/core/lib/Drupal/Core/Recipe/ConfigConfigurator.php) and [Recipe schema validation](../../../../web/core/lib/Drupal/Core/Recipe/Recipe.php) when behavior or syntax is uncertain.

## Choose how to supply each object

| Need | Mechanism |
| --- | --- |
| Reuse configuration already shipped by an extension | List its config names under `config.import.<extension>` |
| Create recipe-owned configuration | Export selected objects into `config/<config_name>.yml` |
| Preserve an existing object and create it only when absent | Supported `createIfNotExists` action |
| Change selected settings, permissions or display components | Config actions |
| Ship nodes, terms, media or custom block content | `content/`, using the content export reference |

During recipe-driven module installation, simple configuration is installed; configuration entities are controlled by the recipe. Explicitly select needed extension configuration. `'*'` includes install and optional configuration, so inspect dependencies before using it. Omitting an extension from `config.import` does not prevent its simple defaults from being installed.

The recipe's `config/` takes precedence over imported extension definitions for creation. Existing active configuration is not a whole-object overwrite target. For profile conversions, express changes to existing configuration as actions instead of copying the profile's override wholesale.

Export active config to a temporary directory, then select only owned objects and required dependencies:

```bash
ddev drush config:export --destination=/tmp/recipe-config-export -y
```

That destination is inside the container. Copy selected files through `ddev exec`. Remove top-level `uuid` and `_core` from reusable config exports. Preserve meaningful nested UUIDs, such as image effect identifiers, and all content UUIDs. Never ship a complete site export, `core.extension`, site-specific secrets or unrelated configuration as recipe defaults.

## Conflicts are an authoring decision

- `config.strict: true` is the installed default: existing supplied objects must match, after core's comparison normalization.
- `false` allows existing objects to remain; it does not overwrite them or suppress config actions.
- A list applies strict comparison only to the listed config names. Use explicit field-storage names when their structure must match; other objects can remain as they are.

Do not disable strictness merely to hide a failure. Compare the object, decide which properties matter, and use a targeted action or change the recipe's documented prerequisites. Strict checks happen during recipe construction, before actions can resolve a conflicting supplied object.

Core provides useful contrasts: `page_content_type` uses the default strictness; media recipes protect their field storage; `administrator_role` preserves any existing administrator role; `standard` deliberately treats its supplied configuration strictly.

## Use actions with verified arguments

Example fragment; the role and display must already exist, or be created by a preceding recipe/action:

```yaml
config:
  actions:
    system.site:
      simpleConfigUpdate:
        page.front: /node
    user.role.content_editor:
      grantPermission: 'access content overview'
    core.entity_form_display.node.page.default:
      setComponent:
        name: body
        options:
          type: text_textarea_with_summary
          weight: 10
          region: content
```

Prefer permission actions over replacing the full permissions array, and component actions over replacing a whole display. The plural `setComponents` form takes a list of `name` / `options` mappings; see `article_content_type`. Some actions require an existing config entity; `createIfNotExists` is not a universal action for arbitrary simple config.

Verify action IDs, entity applicability and argument structure in installed plugins and entity methods. Search `web/core/lib/Drupal/Core/Config/Action/`, relevant entity classes and contributed providers. A YAML parser cannot check these semantics.

## Inputs when values vary by application

Use inputs for values that should be chosen at application time. Example for a recipe directory named `site_identity`:

```yaml
name: Site identity
input:
  site_name:
    description: Public site name
    data_type: string
    default:
      source: value
      value: Example site
config:
  actions:
    system.site:
      simpleConfigUpdate:
        name: '${site_name}'
```

On verified core 11.4:

```bash
ddev exec php vendor/bin/dr recipe:apply recipes/site_identity --input='site_identity.site_name=Example site'
```

The input namespace is the recipe directory name, including for dependencies. Inputs require a description, supported primitive data type and default definition. The installed schema also supports constraints, prompts and defaults from config or environment variables. Substitution is implemented in config-action targets and data; do not assume all files support templating. Keep secrets in environment variables, with Key entities where appropriate; do not persist secrets in exported config.

Further reading: [config actions](https://project.pages.drupalcode.org/distributions_recipes/config_actions.html) and [author guide](https://project.pages.drupalcode.org/distributions_recipes/recipe_author_guide.html). Prefer installed implementations when documentation differs.
