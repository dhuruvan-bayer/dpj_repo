# OpenProject DsoOs Plugin

TODO: Add description of your plugin.

## Installation

Add this plugin to your OpenProject installation by adding the following to `Gemfile.plugins`:

```ruby
group :opf_plugins do
  gem 'openproject-dso_os', git: 'https://github.com/your-org/openproject-dso_os.git', branch: 'main'
end
```

Then run:

```bash
./bin/setup_dev
bundle exec rails db:migrate
```

## Development

### Prerequisites

- OpenProject development environment ([setup guide](https://www.openproject.org/docs/development/development-environment-docker/))
- Ruby version matching OpenProject core

### Local Development

1. Clone this repository alongside your OpenProject core installation
2. Add to `Gemfile.plugins`:

```ruby
group :opf_plugins do
  gem 'openproject-dso_os', path: '../openproject-dso_os'
end
```

3. Run `./bin/setup_dev` from OpenProject core
4. Start development server: `./bin/rails server`

### Configure SonarQube

The SonarQube workflow needs a SonarQube project key stored as a GitHub repository variable. Use [Bayer SonarQube](https://docs.int.bayer.com/cloud/devops/sonarqube/) at **https://sonar.cloud.bayer.com** and follow these steps:

1. **Create a new project** — In [SonarQube](https://sonar.cloud.bayer.com), create a new project. See [Creating your project](https://docs.sonarsource.com/sonarqube-server/project-administration/creating-your-project) for guidance.

2. **Add the GitHub repository to the project** — Associate your plugin's GitHub repo with the SonarQube project (e.g. via GitHub integration or import). See [Importing GitHub repositories](https://docs.sonarsource.com/sonarqube-server/devops-platform-integration/github-integration/importing-github-repositories).

3. **Find the project key** — The project key is shown in the project's settings or on the project homepage in SonarQube. Copy this value. See [Changing the project key](https://docs.sonarsource.com/sonarqube-server/project-administration/maintaining-project/changing-project-key) for where it appears.

4. **Add the variable in GitHub** — Open your repository's Actions variables page:

   **https://github.com/YOUR_ORG/YOUR_REPO/settings/actions**

   Open the **Variables** tab, then add a new repository variable:

   - **Name** (copy exactly):

     ```
     FAWKES_SONAR_PROJECT_KEY
     ```

   - **Value:** the SonarQube project key from step 3.

That's it! The reusable workflow automatically uses the project key from your repository variable.

> **Note:** This README is focused on the template and initial setup. Once you've completed the steps above (including SonarQube configuration), you may want to trim or adapt it for your plugin—for example, the SonarQube section is only relevant until you've done it and can be removed or shortened afterward.

### Running Tests

From the OpenProject core directory:

```bash
RAILS_ENV=test bundle exec rspec $(bundle show openproject-dso_os)/spec
```

## License

GPLv3 - See LICENSE file for details.
