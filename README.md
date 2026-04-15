# OpenProject DsoOs Plugin

The OpenProject DsoOs plugin extends OpenProject's version management with wiki page integration. It provides a custom API endpoint that surfaces wiki pages linked to project versions, enabling teams to associate release documentation directly with version records and retrieve them via a structured, paginated API.

## Features

- **Version-Wiki Page Linking**: Associate wiki pages with project versions using a `wiki_page_title` field on the version record
- **Custom API Endpoint**: Paginated `GET /api/v3/projects/:project_identifier/wiki_pages` endpoint that returns only wiki pages linked to versions, with the associated version data embedded in each response element
- **Homescreen Block**: Renders a custom block on the OpenProject homescreen
- **Hook-based Extensibility**: Built-in hook listener (`Hooks`) ready to extend layouts and controller callbacks

## Pre-requisites

In order to be able to continue, you will first have to have a working OpenProject core development environment. Please follow these guides to set that up:

- [Development environment Ubuntu/Debian](https://www.openproject.org/docs/development/development-environment-ubuntu/)
- [Development environment Mac OS X](https://www.openproject.org/docs/development/development-environment-osx/)
- [Development environment Docker](https://www.openproject.org/docs/development/development-environment-docker/)

We are assuming that you understand how to develop Ruby on Rails applications and are familiar with controllers, views, asset management, hooks and engines.

To get started with a development environment of the OpenProject core, we recommend you follow our development guides at [https://docs.openproject.org/development/](https://docs.openproject.org/development/) as well as the [guide for plugin development](https://www.openproject.org/docs/development/create-openproject-plugin).

## Getting started

To include this plugin, you need to create a file called `Gemfile.plugins` in your OpenProject core directory with the following contents:

```ruby
group :opf_plugins do
  gem "openproject-dso_os", git: "https://github.com/your-org/openproject-dso_os.git", branch: "main"
end
```

As you may want to play around with and modify the plugin locally, you may want to check it out first and use the following instead to reference a local path:

```ruby
group :opf_plugins do
  gem "openproject-dso_os", path: "/path/to/openproject-dso_os"
end
```

If you already have a `Gemfile.plugins` just add the `gem` line to it inside the `:opf_plugins` group.

Once you've done that, switch to the OpenProject core directory and run:

```bash
./bin/setup_dev
```

While you're in the root of the OpenProject core, we recommend you export the OpenProject core path as `$OPENPROJECT_ROOT`:

```bash
export OPENPROJECT_ROOT=$(pwd)
```

## Usage

### Prerequisites

- The project must have the **Wiki** module enabled (`Project Settings → Modules → Wiki`)
- At least one version must have its `wiki_page_title` field set to the exact title of an existing wiki page
- Requests must be authenticated with a valid API key (`My Account → Access Tokens → API`)

### Step 1 — Link a Version to a Wiki Page

In OpenProject, open a project version and set the **Wiki page** field to the exact title of an existing wiki page in that project. This is the `wiki_page_title` attribute on the `Version` record.

Only versions with a non-empty `wiki_page_title` that matches an existing wiki page title will appear in the API response.

### Step 2 — Retrieve Wiki Pages via API

```
GET /api/v3/projects/:project_identifier/wiki_pages
```

`:project_identifier` is the project's URL slug (e.g. `dhuruvan-project`), visible in **Project Settings → General** or in the browser URL when inside a project.

**Authentication:**

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  "http://localhost:3000/api/v3/projects/dhuruvan-project/wiki_pages"
```

You can find or generate your API key at `http://localhost:3000/my/access_token`.

**Query Parameters:**

| Parameter  | Default | Constraints | Description |
|------------|---------|-------------|-------------|
| `offset`   | `1`     | ≥ 1         | Page number (1-based) |
| `pageSize` | `20`    | 1–100       | Number of results per page |

**Example request:**

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  "http://localhost:3000/api/v3/projects/my-project/wiki_pages?offset=1&pageSize=2"
```

**Example response:**

```json
{
  "total": 3,
  "count": 2,
  "pageSize": 2,
  "offset": 1,
  "data": [
    {
      "id": 12,
      "title": "first version release notes",
      "created_at": "2026-04-14T05:09:24.000Z",
      "updated_at": "2026-04-14T05:33:53.000Z",
      "linked_version": {
        "id": 25,
        "name": "first version",
        "status": "open",
        "wiki_page_title": "first version release notes",
        "effective_date": "2026-04-14",
        "start_date": "2026-04-06"
      }
    },
    {
      "id": 15,
      "title": "Second version",
      "created_at": "2026-04-14T06:47:05.000Z",
      "updated_at": "2026-04-14T10:26:00.000Z",
      "linked_version": {
        "id": 27,
        "name": "2nd version",
        "status": "open",
        "wiki_page_title": "Second version",
        "effective_date": null,
        "start_date": null
      }
    }
  ]
}
```

**Response fields:**

| Field       | Description |
|-------------|-------------|
| `total`     | Total number of wiki pages linked to versions in this project |
| `count`     | Number of results in the current page |
| `pageSize`  | Page size used for this request |
| `offset`    | Current page number |
| `data`      | Array of wiki page objects, each with an embedded `linked_version` |

Only wiki pages whose `title` exactly matches the `wiki_page_title` of a version in the project are returned. Results are ordered by wiki page `id`.

## Plugin Structure

```
openproject-dso_os/
├── lib/
│   ├── api/
│   │   └── v3/
│   │       └── wiki_pages/
│   │           └── wiki_pages_by_project_api.rb  # Custom API endpoint
│   └── open_project/
│       └── dso_os/
│           ├── engine.rb                          # Plugin engine, route & menu registration
│           ├── hooks.rb                           # Hook listener for view/controller extension
│           └── version.rb                         # Plugin version (7.1.0)
└── spec/
    └── spec_helper.rb
```

### Key Components

- **`WikiPagesByProjectAPI`**: Grape API endpoint mounted inside OpenProject's existing `projects/:id` route tree via `API::V3::Workspaces::NestedApis`. Uses `@project` set by the core's `ProjectsAPI` — inheriting visibility, admin scoping, and error handling automatically.
- **`Engine`**: Registers the project module, permissions, project menu entry, homescreen block, and mounts the API endpoint.
- **`Hooks`**: `ViewListener` subclass — ready to render partials into layout hooks (sidebar, head, homescreen links).

## Development

### Running Tests

From the OpenProject core directory:

```bash
RAILS_ENV=test bundle exec rspec $(bundle show openproject-dso_os)/spec
```

Or using Docker:

```bash
docker compose run --rm backend-test "bundle exec rspec $(bundle show openproject-dso_os)/spec"
```

### Configure SonarQube

The SonarQube workflow needs a SonarQube project key stored as a GitHub repository variable. Use [Bayer SonarQube](https://docs.int.bayer.com/cloud/devops/sonarqube/) at **https://sonar.cloud.bayer.com** and follow these steps:

1. **Create a new project** — In [SonarQube](https://sonar.cloud.bayer.com), create a new project. See [Creating your project](https://docs.sonarsource.com/sonarqube-server/project-administration/creating-your-project) for guidance.

2. **Add the GitHub repository to the project** — Associate your plugin's GitHub repo with the SonarQube project. See [Importing GitHub repositories](https://docs.sonarsource.com/sonarqube-server/devops-platform-integration/github-integration/importing-github-repositories).

3. **Find the project key** — The project key is shown in the project's settings in SonarQube. Copy this value.

4. **Add the variable in GitHub** — Open your repository's Actions variables page:

   ```
   https://github.com/YOUR_ORG/YOUR_REPO/settings/actions
   ```

   Open the **Variables** tab and add a new repository variable:

   - **Name**: `FAWKES_SONAR_PROJECT_KEY`
   - **Value**: the SonarQube project key from step 3

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

Please ensure all tests pass and follow OpenProject's Ruby style guide (enforced via RuboCop).

## Troubleshooting

### 404 on `/api/v3/projects/:project_identifier/wiki_pages`

- **Unauthenticated request**: Include a valid `Authorization: Bearer YOUR_API_KEY` header. The anonymous user cannot see non-public projects.
- **Project not found**: Verify the project identifier is correct and the authenticated user has access.
- **No linked versions**: The endpoint only returns wiki pages whose titles match a version's `wiki_page_title`. If no versions have `wiki_page_title` set, the response will be empty.
- **No wiki**: The project must have the wiki module enabled.

## License

GPLv3 — See LICENSE file for details.

## Credits

Developed by the Bayer OpenProject team.
