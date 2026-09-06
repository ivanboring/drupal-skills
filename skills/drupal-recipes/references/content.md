# Export content for recipes

Choose commands using the installed core version and command help. Content export is separate from config export: bundles and fields belong in configuration; nodes, media, taxonomy terms and custom block content belong in `content/`.

## Core export: preferred on Drupal 11.3+

Core gained `content:export` in 11.3. On this project's verified Drupal 11.4.6, use the Composer binary from the project root:

```bash
ddev exec php vendor/bin/dr help content:export
ddev exec php vendor/bin/dr content:export node 39 --with-dependencies --dir=/var/www/html/recipes/my_recipe/content
```

Replace the example node ID and recipe path with the requested content. The exporter writes `content/<entity_type>/<uuid>.yml` and copies associated file attachments. Prefer `--dir` to redirecting console output: it preserves attachments and separates YAML from command diagnostics.

For one entity without recursively exported references:

```bash
ddev exec php vendor/bin/dr content:export node 39 --dir=/var/www/html/recipes/my_recipe/content
```

For selected bundles, or an entire entity type:

```bash
ddev exec php vendor/bin/dr content:export node --bundle=page --bundle=article --with-dependencies --dir=/var/www/html/recipes/my_recipe/content
ddev exec php vendor/bin/dr content:export media --with-dependencies --dir=/var/www/html/recipes/my_recipe/content
```

Omitting the ID exports matching entities. `--bundle` is repeatable; `-W` means `--with-dependencies`. A directory is required for multiple entities or recursive export. Export one entity type at a time; there is no all-types argument. A successful bulk command can export zero entities, so inspect the output count.

On Drupal 11.3, verify and use the older entry point from the web root:

```bash
ddev exec -d /var/www/html/web php core/scripts/drupal content:export node 39 --with-dependencies --dir=../recipes/my_recipe/content
```

Do not copy the older author guide's claim that core cannot export content. The dedicated [default content guide](https://project.pages.drupalcode.org/distributions_recipes/default_content.html) explains the version distinction. Drupal 11.4's [CLI change record](https://www.drupal.org/node/3584928) documents the move to `vendor/bin/dr`.

## Older core: optional Default Content 2.x

If core lacks the command, check whether Default Content 2.x is already present and whether its Drush commands are available:

```bash
ddev drush help default-content-export-references
ddev drush help default-content-export
```

If installation or enabling is necessary, ask the user first under this project's policy and take the baseline dump before changing the site. Verify current compatible releases rather than installing an arbitrary version.

With the module and its commands available:

```bash
ddev drush default-content-export-references node 39 --folder=/var/www/html/recipes/my_recipe/content
ddev drush default-content-export node 39 --file=/var/www/html/recipes/my_recipe/content/node-39.yml
```

Aliases are `dcer` and `dce`. Create the destination directory for single-file export first. The single-entity command does not recursively export dependencies. These are contributed commands, not built-in Drush equivalents of core's `content:export`. The export module is not required merely to import recipe content with core.

## Review before packaging and retrying

- Export deliberately selected sample content. Recursive export may include authors, media, files and terms; inspect that dependency closure before committing it.
- Preserve `_meta.uuid`, `_meta.depends`, translations and exported reference values. Numeric source IDs are not portable target IDs.
- Ensure the recipe provides the required bundles, fields, languages and text formats before importing content. Content dependency export does not export their configuration.
- Inspect copied files, file paths and links. Do not assume hard-coded `/node/39` links will be remapped. Verify custom field types and embedded references on the destination.
- Re-exporting overwrites matching UUID filenames and attachments but does not clean obsolete exports. Review stale files explicitly.
- Keep the exported recipe files outside any filesystem rollback set. Export before restoring a site used to prepare fixtures.
- Recipe application imports content after configuration. The installed runner uses `Existing::Skip`: existing UUIDs are skipped. Reapplying after editing content YAML does not update that content. Restore the original baseline to test a new import.

Local evidence: [ContentExportCommand](../../../../web/core/lib/Drupal/Core/DefaultContent/Command/ContentExportCommand.php), [Exporter](../../../../web/core/lib/Drupal/Core/DefaultContent/Exporter.php), [ExportMetadata](../../../../web/core/lib/Drupal/Core/DefaultContent/ExportMetadata.php), and [basic_shortcuts content](../../../../web/core/recipes/basic_shortcuts/content).
