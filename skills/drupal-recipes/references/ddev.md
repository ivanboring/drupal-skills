# DDEV baseline, apply, restore and retry

Read this before recipe work. Always take a database dump before the first site-changing operation, including preparing content/config in the UI, enabling extensions, or applying a recipe. Preserve that original baseline throughout the task. Before each later attempt, take a separate checkpoint; never replace the original with a partially modified database.

Documentation-only edits and static file inspection do not require changing or restoring the site.

## Establish the environment

Run commands from the host project root through DDEV. Inside `ddev ssh`, run PHP, Composer and Drush directly; do not nest DDEV. Host-side `ddev export-db` / `import-db` remain the preferred backup and restore operations. If working entirely inside the web container, a Drush SQL dump/import is an alternative, but verify its driver-specific options and exact database reset procedure before use.

Check `ddev describe`, `ddev drush status`, core version, document root, database and target URI. For this project, the container root is `/var/www/html`, the docroot is `web`, and the browser URL is `https://observability_recipe.ddev.site`. The hostname `web` is container-internal.

On verified Drupal 11.4.6, these commands work from the project root:

```bash
ddev exec php vendor/bin/dr --version
ddev exec php vendor/bin/dr help recipe:apply
ddev exec php vendor/bin/dr help content:export
ddev drush help recipe
```

Use `vendor/bin/dr` on 11.4+, checking installed help. Directly invoking `core/scripts/drupal` is deprecated; in this relocated-docroot project it also failed to locate the Composer autoloader. Do not modify core or add vendor symlinks to work around it.

For older supported releases, verify `php core/scripts/drupal` from the web root. Do not assume a `ddev drupal` helper exists. For multisite, select the same target for inspection, application, export and restore; core 11.4 uses `--url`, while Drush uses `--uri`.

## Take and verify the original dump

Use a unique run directory outside the web root. The commands below use host shell variables and container commands for filesystem work:

```bash
recipe_run_id=$(ddev exec date -u +%Y%m%dT%H%M%S%N)
ddev exec bash -c 'umask 077; mkdir -p "$1"; printf "*\n" > "$1/.gitignore"' _ .ddev/.recipe-backups
ddev exec mkdir -p ".ddev/.recipe-backups/$recipe_run_id"
recipe_backup=".ddev/.recipe-backups/$recipe_run_id/baseline.sql.gz"
ddev export-db --database=db --file="$recipe_backup"
ddev exec test -s "$recipe_backup"
ddev exec gzip -t "$recipe_backup"
ddev exec sha256sum "$recipe_backup"
```

Check each exit status and stop if export or verification fails. Adapt `db` to the verified target database. The export path is host-relative; the same relative path is visible from the container project root. A host `/tmp` path and a container `/tmp` path are different locations.

Record the exact dump path, checksum, DDEV project, database and target URI in the task notes so a fresh shell or resumed agent can restore the correct baseline. Keep dumps uncommitted. A nonempty, valid gzip verifies the archive, not full restorability; a successful restore and site check are stronger evidence.

## Apply and inspect

Only after the verified dump and any required module approval:

```bash
ddev exec php vendor/bin/dr recipe:info recipes/my_recipe
ddev exec php vendor/bin/dr recipe:apply recipes/my_recipe -v
ddev drush cache:rebuild
```

`recipe:info` constructs the recipe and checks some prerequisites; it is not a full dry run and does not execute actions. Do not invent a `--dry-run` option. The verified Drush alternative is `ddev drush recipe /var/www/html/recipes/my_recipe`; use one apply command, not both.

Older-core application example:

```bash
ddev exec -d /var/www/html/web php core/scripts/drupal recipe ../recipes/my_recipe
```

Check outcomes in config, content and the browser. Keep command errors and identify the failed phase before deciding what to change.

## Restore before a clean retry

A retry against partially applied state is not a clean test. Preserve any wanted config/content exports and recipe edits first. Take another uniquely named database dump before overwriting the current database, especially if it contains work needed for diagnosis.

Then restore the original recorded baseline:

```bash
ddev import-db --database=db --file="$recipe_backup"
ddev drush cache:rebuild
ddev drush status
```

Recover `recipe_backup` from task notes if the shell changed; never guess the latest dump. Default DDEV import drops the target database before importing. Do not use `--no-drop`, which can leave tables from the failed attempt.

Restoring this task's isolated local test database is part of the retry workflow. If someone has added unrelated work since the baseline or the target is shared, preserve it and resolve the scope before overwriting it.

Database restoration does not restore uploaded/private files, Composer files, installed package code or external side effects. Before testing content imports or other file-changing operations, archive the relevant public/private file directories outside the web root and record their original presence. Restore those directories to their baseline contents, including removing only files created by the test, when a full site reset is required. Preserve authored recipe files separately. Record and restore only task-owned Composer/code changes when necessary; do not reset unrelated user work.

After restoring, verify the baseline's relevant config and content, fix the recipe, take a fresh attempt checkpoint, and reapply. For an explicit idempotence check, apply twice without restoring between applications, keeping both the original baseline and a checkpoint before the second application.

At completion, leave the successfully applied state only if application was requested. For temporary authoring tests, restore the original state after validation. Report whether the site is applied or restored and retain the baseline path for recovery.

Sources: installed `ddev export-db --help`, `ddev import-db --help`, and core/Drush command help; [DDEV export](https://docs.ddev.com/en/stable/users/usage/commands/#export-db), [DDEV import](https://docs.ddev.com/en/stable/users/usage/commands/#import-db), [Drupal CLI change](https://www.drupal.org/node/3584928).
