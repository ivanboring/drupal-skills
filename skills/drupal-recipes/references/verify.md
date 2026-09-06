# Validate and find examples

## Verify behavior, not only YAML syntax

1. Parse all recipe/config/content YAML and validate distributable Composer JSON. Check required extensions, recipe paths, config dependencies, action availability and version constraints.
2. Inspect with the installed `recipe:info` command when available. It can report construction errors but cannot prove that actions or content imports will succeed.
3. Follow the DDEV baseline procedure. Apply to a disposable minimal installation to detect hidden dependencies, and to a restored copy of the intended existing site to detect collisions. Never reinstall the working site merely to obtain a minimal test.
4. Check the stated outcomes: fields and display widgets/formatters, effective permissions for intended roles, workflows, imported content, translations, UUID references and actual files. Check preserved settings as well as newly created objects.
5. Reapply once without a restore to test idempotence; restore the original baseline before testing a revised recipe's first application. Existing content UUIDs are skipped, so repeat application alone cannot validate edited content fixtures.
6. Retain evidence of the baseline, command exit statuses, outcome checks and final site state. Do not claim runtime verification if only static checks ran.

Core's [GenericRecipeTestBase](../../../../web/core/modules/system/tests/src/Functional/Recipe/GenericRecipeTestBase.php) creates a minimal site and applies a recipe twice. Its recipe-local subclasses use `tests/src/Functional/GenericTest.php`, PHPUnit group attributes and `RunTestsInSeparateProcesses`. It is a useful pattern, but success alone does not assert your feature's behavior. When adding PHPUnit coverage, follow the available Drupal automated-testing skill and the project's test environment configuration; do not blindly copy core namespaces into a contributed package.

## Local examples reviewed

Reviewed all 138 files under `recipes/` and `web/core/recipes/` on 2026-09-05, with installed Drupal 11.4.6. The custom directory contained only [README.txt](../../../../recipes/README.txt). Core contained 28 recipe definitions, their configuration/content, and 27 generic test subclasses. Treat this inventory as a navigation aid; recheck installed files after upgrades.

All names below are directories under [web/core/recipes](../../../../web/core/recipes).

| Need | Read |
| --- | --- |
| Annotated basic syntax | `example` |
| Whole-site composition and permission actions | `standard` |
| Simple content type versus action-built displays | `page_content_type`, `article_content_type` |
| Add optional fields to another recipe | `article_tags`, `article_comment` |
| Shared taxonomy and comment setup | `tags_taxonomy`, `comment_base` |
| Reusable roles and additive permissions | `administrator_role`, `content_editor_role` |
| Block type, fields and displays | `basic_block_type` |
| Text formats and CKEditor configuration | `basic_html_format_editor`, `full_html_format_editor`, `restricted_html_format` |
| Media bundles, source fields, library displays and strict storage | `audio_media_type`, `document_media_type`, `image_media_type`, `local_video_media_type`, `remote_video_media_type` |
| Default content YAML and supporting config | `basic_shortcuts` |
| Workflow definition | `editorial_workflow` |
| Search config and permissions | `content_search` |
| Theme setup, create-if-absent blocks and placement | `core_recommended_admin_theme`, `core_recommended_front_end_theme` |
| Extension-only setup and selective imports | `core_recommended_performance`, `core_recommended_maintenance` |
| Image effects, breakpoints and responsive styles | `standard_responsive_images` |
| User fields, shared storage and displays | `user_picture` |

Do not assume an example grants access to everything it creates. For example, the full HTML recipe does not itself grant a role permission to use that format, and editorial workflow configuration begins without content bundles attached.

## Documentation entry points

- [Drupal Recipes](https://www.drupal.org/docs/extending-drupal/drupal-recipes): official overview.
- [Recipe author guide](https://project.pages.drupalcode.org/distributions_recipes/recipe_author_guide.html): composition, package structure and recipe keys.
- [Recipes Cookbook](https://www.drupal.org/docs/extending-drupal/contributed-modules/contributed-module-documentation/distributions-and-recipes-initiative/recipes-cookbook): contributed examples and authoring tools. Check individual compatibility; this is a catalogue, not a specification.
- [Default content](https://project.pages.drupalcode.org/distributions_recipes/default_content.html): current core export and older contributed workflows.
- [Recipe examples](https://project.pages.drupalcode.org/distributions_recipes/recipe_examples.html): further task-specific examples.

When online guidance conflicts, check versioned local source and CLI help. The author guide's older statement that core cannot export content is superseded by the dedicated default content guide.
