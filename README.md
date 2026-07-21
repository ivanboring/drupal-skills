# drupal-skills

Agent skills for working with Drupal.

## Skills

- **drupal-project-description**: create or edit a project page on drupal.org (the module or theme
  body at `drupal.org/project/<name>`), or generate a `PROJECT_DESCRIPTION.html` file, using the
  special drupal.org formatting classes (note boxes, tip boxes, warning boxes, action buttons,
  grids, side-by-side listings) and a human, non-AI writing voice.
- **drupal-module-documentation**: write end-user and developer documentation for a contrib module
  with MkDocs, build the `docs/` structure, and set up `mkdocs.yml` and `.gitlab-ci.yml` for the
  drupal.org GitLab Pages pipeline.

## Install

Add a skill straight from this repo with the [skills](https://agentskills.io) CLI:

```bash
npx skills add ivanboring/drupal-skills
```

That reads the `skills/` folder and installs the skills into your agent's skills directory.

To install one skill by name:

```bash
npx skills add ivanboring/drupal-skills/drupal-project-description
```

List and manage what you have installed:

```bash
npx skills list
npx skills remove drupal-project-description
```

## Manual install

Clone the repo and symlink the skill into your agent's skills directory:

```bash
git clone git@github.com:ivanboring/drupal-skills.git
ln -s "$PWD/drupal-skills/skills/drupal-project-description" ~/.claude/skills/
```

## Usage

Once installed, ask your agent to write or edit a drupal.org project description, for example:

```
Write a project description for my module at web/modules/contrib/my_module
```

```
Update the description on drupal.org/project/my_module to add a Features section
```

The skill asks where to save the file (default `PROJECT_DESCRIPTION.html` in the module folder)
before writing.
