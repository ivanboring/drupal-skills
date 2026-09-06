# Create a recipe

Start with the DDEV baseline procedure before changing a site. Inspect the installed core version and available recipes before choosing features. Recipes automate an existing site's setup; they are applied, not enabled like modules, and have no uninstall operation. Editing an applied recipe does not update the site automatically.

## Choose the smallest reusable unit

1. Look in `recipes/` and `web/core/recipes/` for reusable work. Keep custom recipes in `recipes/<machine_name>/`; never edit core's copies.
2. Follow the project's module-discovery policy. Prefer core, existing dependencies, and existing recipes. When contributed functionality is needed, use the available module-finder skill, check maintenance, security coverage and core compatibility, and obtain user approval before installing modules. A recipe's `install:` list can install modules too.
3. Separate reusable base configuration from optional integrations. Core's `article_tags` combines `article_content_type` and `tags_taxonomy`, then adds a field and updates displays.
4. Define observable outcomes: extensions enabled, configuration created or changed, permissions granted, content imported, and existing settings preserved.

## Files and dependency names

Only `recipe.yml` is essential. Add `config/*.yml` for new configuration, `content/` for exported content, and `composer.json` for a distributable package. Include a short recipe README with prerequisites, inputs, application command and expected results.

In the installed core, bare names under `recipes:` resolve beside the calling recipe. Names containing a slash resolve relative to the Drupal web root. Therefore a custom recipe outside core should explicitly use `core/recipes/page_content_type`, not assume `page_content_type` finds core automatically. Keep contributed dependencies as sibling directories; avoid cycles.

Example `recipes/editorial_pages/recipe.yml`:

```yaml
name: Editorial pages
description: Adds basic pages and gives content editors permission to create them.
type: Content type
recipes:
  - core/recipes/page_content_type
  - core/recipes/content_editor_role
config:
  actions:
    user.role.content_editor:
      grantPermissions:
        - 'create page content'
        - 'edit own page content'
```

Here the included recipes supply the content type and role. `type` describes a category; it is not a module machine name.

Composer downloads dependencies; `install:` enables extension machine names already present. `recipes:` applies other recipes. Neither list replaces Composer requirements for missing packages.

For distribution, use Composer `type: drupal-recipe` and declare supported core and contributed package versions. For the example above, a project targeting the verified 11.4 series could use:

```json
{
  "name": "example/editorial_pages",
  "description": "Basic pages with content editor permissions.",
  "type": "drupal-recipe",
  "license": "GPL-2.0-or-later",
  "require": {
    "drupal/core": "^11.4"
  }
}
```

Choose the core constraint from the APIs and versions actually tested. Use real package names for additional dependencies; core extension names such as `node` are not separate Composer packages.

Check the site's `extra.installer-paths`, `composer/installers`, and `drupal/core-recipe-unpack` setup. This project already installs `drupal-recipe` packages into `recipes/{$name}`. Unpacking moves recipe dependencies into the root Composer requirements; it does not apply the recipe. Review Composer changes and preserve locally authored recipes in version control even when downloaded recipes are ignored.

## Execution model

The installed `RecipeRunner` processes included recipes, installs modules then themes, imports missing configuration, runs configuration actions in declaration order, imports content, and dispatches the applied event. This is not a general PHP script runner. Put runtime behavior in an appropriate module, and use supported config actions for setup.

Do not promise atomic rollback or automatic idempotence. A failed action may leave earlier work applied. Use the baseline restore procedure for a clean retry.

Sources: [Drupal Recipes](https://www.drupal.org/docs/extending-drupal/drupal-recipes), [author guide](https://project.pages.drupalcode.org/distributions_recipes/recipe_author_guide.html), [cookbook](https://www.drupal.org/docs/extending-drupal/contributed-modules/contributed-module-documentation/distributions-and-recipes-initiative/recipes-cookbook), [packaging and application](https://project.pages.drupalcode.org/distributions_recipes/getting_started.html). Verify discovery and execution against local [RecipeConfigurator](../../../../web/core/lib/Drupal/Core/Recipe/RecipeConfigurator.php) and [RecipeRunner](../../../../web/core/lib/Drupal/Core/Recipe/RecipeRunner.php).
