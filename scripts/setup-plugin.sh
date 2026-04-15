#!/bin/bash
#
# setup-plugin.sh - Transform the OpenProject plugin template into a new plugin
#
# Usage:
#   ./scripts/setup-plugin.sh <plugin_name> [options]
#
# Arguments:
#   plugin_name    Required. The name of your plugin in snake_case (e.g., my_feature)
#
# Options:
#   --clean        Remove all example code (models, controllers, specs, images)
#   --help         Show this help message
#
# Example:
#   ./scripts/setup-plugin.sh my_awesome_feature --clean
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
CLEAN_MODE=false
PLUGIN_NAME=""

# Helper functions
print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "     $1"
}

show_help() {
    head -25 "$0" | tail -20 | sed 's/^#//' | sed 's/^ //'
    exit 0
}

# Convert snake_case to PascalCase (works on both macOS and Linux)
to_pascal_case() {
    local input="$1"
    local result=""
    local capitalize_next=true
    
    for (( i=0; i<${#input}; i++ )); do
        local char="${input:$i:1}"
        if [[ "$char" == "_" ]]; then
            capitalize_next=true
        elif [[ "$capitalize_next" == true ]]; then
            result+=$(echo "$char" | tr '[:lower:]' '[:upper:]')
            capitalize_next=false
        else
            result+="$char"
        fi
    done
    
    echo "$result"
}

# Validate plugin name (must be snake_case)
validate_plugin_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z][a-z0-9_]*$ ]]; then
        print_error "Plugin name must be in snake_case (e.g., my_feature)"
        print_error "Got: '$name'"
        exit 1
    fi
    if [[ "$name" == "custom_links" ]]; then
        print_error "Plugin name cannot be 'custom_links' (that's the template name)"
        exit 1
    fi
}

# Check if setup has already been run
check_already_run() {
    if [[ ! -f "$PROJECT_ROOT/lib/open_project/custom_links.rb" ]]; then
        print_error "Setup has already been run or template files are missing."
        print_error "This script should only be run once on a fresh template."
        exit 1
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                CLEAN_MODE=true
                shift
                ;;
            --help|-h)
                show_help
                ;;
            -*)
                print_error "Unknown option: $1"
                show_help
                ;;
            *)
                if [[ -z "$PLUGIN_NAME" ]]; then
                    PLUGIN_NAME="$1"
                else
                    print_error "Unexpected argument: $1"
                    show_help
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$PLUGIN_NAME" ]]; then
        print_error "Plugin name is required"
        show_help
    fi
}

# Rename directories
rename_directories() {
    echo ""
    echo "Renaming directories..."
    
    local dirs_to_rename=(
        "app/seeders/basic_data/custom_links:app/seeders/basic_data/$PLUGIN_NAME"
        "app/views/hooks/custom_links:app/views/hooks/$PLUGIN_NAME"
        "lib/open_project/custom_links:lib/open_project/$PLUGIN_NAME"
    )
    
    for pair in "${dirs_to_rename[@]}"; do
        local old_dir="${pair%%:*}"
        local new_dir="${pair##*:}"
        
        if [[ -d "$PROJECT_ROOT/$old_dir" ]]; then
            mv "$PROJECT_ROOT/$old_dir" "$PROJECT_ROOT/$new_dir"
            print_success "Renamed $old_dir -> $new_dir"
        else
            print_warning "Directory not found: $old_dir (skipping)"
        fi
    done
}

# Rename files
rename_files() {
    echo ""
    echo "Renaming files..."
    
    local files_to_rename=(
        "openproject-custom_links.gemspec:openproject-$PLUGIN_NAME.gemspec"
        "lib/openproject-custom_links.rb:lib/openproject-$PLUGIN_NAME.rb"
        "lib/open_project/custom_links.rb:lib/open_project/$PLUGIN_NAME.rb"
    )
    
    for pair in "${files_to_rename[@]}"; do
        local old_file="${pair%%:*}"
        local new_file="${pair##*:}"
        
        if [[ -f "$PROJECT_ROOT/$old_file" ]]; then
            mv "$PROJECT_ROOT/$old_file" "$PROJECT_ROOT/$new_file"
            print_success "Renamed $old_file -> $new_file"
        else
            print_warning "File not found: $old_file (skipping)"
        fi
    done
}

# Update file contents with sed (portable for macOS and Linux)
sed_inplace() {
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# Replace content in all relevant files
replace_content() {
    echo ""
    echo "Updating file contents..."
    
    local pascal_name=$(to_pascal_case "$PLUGIN_NAME")
    
    # Find all text files and replace content
    # Using find to get all relevant files
    local files_to_update=$(find "$PROJECT_ROOT" \
        -type f \
        \( -name "*.rb" -o -name "*.gemspec" -o -name "*.yml" -o -name "*.erb" -o -name "*.md" -o -name "*.json" -o -name "routes.rb" \) \
        ! -path "*/scripts/*" \
        ! -path "*/.git/*" \
        2>/dev/null || true)
    
    local count=0
    for file in $files_to_update; do
        if [[ -f "$file" ]]; then
            # Check if file contains any of the patterns
            if grep -q -E "(custom_links|CustomLinks|openproject-custom_links|openproject_custom_links)" "$file" 2>/dev/null; then
                # Replace all variations
                sed_inplace "s/CustomLinks/$pascal_name/g" "$file"
                sed_inplace "s/custom_links/$PLUGIN_NAME/g" "$file"
                sed_inplace "s/openproject-custom_links/openproject-$PLUGIN_NAME/g" "$file"
                sed_inplace "s/openproject_custom_links/openproject_$PLUGIN_NAME/g" "$file"
                count=$((count + 1))
            fi
        fi
    done
    
    print_success "Updated $count files with new plugin name"
    
    # Update gemspec author info
    local gemspec="$PROJECT_ROOT/openproject-$PLUGIN_NAME.gemspec"
    if [[ -f "$gemspec" ]]; then
        sed_inplace 's/s.authors.*/s.authors     = "Your Name"/' "$gemspec"
        sed_inplace 's/s.email.*/s.email       = "your.email@example.com"/' "$gemspec"
        sed_inplace 's|s.homepage.*|s.homepage    = "https://github.com/your-org/openproject-'"$PLUGIN_NAME"'"|' "$gemspec"
        sed_inplace "s/s.summary.*/s.summary     = 'OpenProject ${pascal_name} Plugin'/" "$gemspec"
        sed_inplace 's/s.description.*/s.description = "TODO: Add plugin description"/' "$gemspec"
        print_success "Updated gemspec metadata"
    fi
}

# Create SonarQube configuration
create_sonarqube_config() {
    echo ""
    echo "Creating SonarQube configuration..."
    
    # Create .github/workflows directory
    mkdir -p "$PROJECT_ROOT/.github/workflows"
    
    # Create sonarqube.yml workflow
    cat > "$PROJECT_ROOT/.github/workflows/sonarqube.yml" << 'WORKFLOW_EOF'
# Calls the reusable SonarQube workflow from eep-da-dpj
# Runs tests with coverage, RuboCop linting, and performs SonarQube scan

name: SonarQube Scan

on:
  workflow_dispatch:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  id-token: write
  contents: read

jobs:
  sonar:
    uses: bayer-int/eep-da-dpj/.github/workflows/_SonarQube.yaml@main
    secrets: inherit
    with:
      sonar_project_key: ${{ vars.FAWKES_SONAR_PROJECT_KEY }}
      run_tests: true
      plugin_name: PLUGIN_NAME_PLACEHOLDER
      run_rubocop: true
      enforce_quality_gate: false  # Set to true to fail on Quality Gate failure
WORKFLOW_EOF
    
    # Replace placeholder with actual plugin name
    sed_inplace "s/PLUGIN_NAME_PLACEHOLDER/openproject-$PLUGIN_NAME/g" "$PROJECT_ROOT/.github/workflows/sonarqube.yml"
    print_success "Created .github/workflows/sonarqube.yml"
    
    # Create sonar-project.properties
    cat > "$PROJECT_ROOT/sonar-project.properties" << SONAR_EOF
# SonarQube Project Configuration
# NOTE: sonar.projectKey is automatically provided by the reusable workflow
# from FAWKES_SONAR_PROJECT_KEY repository variable - no need to set it here!

# Project name (for display in SonarQube UI)
sonar.projectName=openproject-$PLUGIN_NAME

# Encoding
sonar.sourceEncoding=UTF-8
SONAR_EOF
    print_success "Created sonar-project.properties"
}

# Clean example code
clean_examples() {
    echo ""
    echo "Cleaning example code..."
    
    # Remove images directory
    if [[ -d "$PROJECT_ROOT/images" ]]; then
        rm -rf "$PROJECT_ROOT/images"
        print_success "Removed images/"
    fi
    
    # Remove example specs (keep spec_helper.rb)
    local spec_dirs_to_remove=(
        "spec/controllers"
        "spec/factories"
        "spec/features"
    )
    for dir in "${spec_dirs_to_remove[@]}"; do
        if [[ -d "$PROJECT_ROOT/$dir" ]]; then
            rm -rf "$PROJECT_ROOT/$dir"
            print_success "Removed $dir/"
        fi
    done
    
    # Remove example migrations
    if [[ -d "$PROJECT_ROOT/db/migrate" ]]; then
        rm -rf "$PROJECT_ROOT/db/migrate"
        print_success "Removed db/migrate/"
    fi
    
    # Remove example models (keep application_record.rb)
    if [[ -f "$PROJECT_ROOT/app/models/test.rb" ]]; then
        rm -f "$PROJECT_ROOT/app/models/test.rb"
        print_success "Removed app/models/test.rb"
    fi
    
    # Remove example controller
    if [[ -f "$PROJECT_ROOT/app/controllers/test_controller.rb" ]]; then
        rm -f "$PROJECT_ROOT/app/controllers/test_controller.rb"
        print_success "Removed app/controllers/test_controller.rb"
    fi
    
    # Remove example views
    if [[ -d "$PROJECT_ROOT/app/views/test" ]]; then
        rm -rf "$PROJECT_ROOT/app/views/test"
        print_success "Removed app/views/test/"
    fi
    
    # Remove example seeder
    if [[ -f "$PROJECT_ROOT/app/seeders/basic_data/$PLUGIN_NAME/test_seeder.rb" ]]; then
        rm -f "$PROJECT_ROOT/app/seeders/basic_data/$PLUGIN_NAME/test_seeder.rb"
        print_success "Removed example seeder"
    fi
    
    # Remove travis.yml (legacy CI)
    if [[ -f "$PROJECT_ROOT/.travis.yml" ]]; then
        rm -f "$PROJECT_ROOT/.travis.yml"
        print_success "Removed .travis.yml"
    fi
}

# Update README with plugin-specific content
update_readme() {
    echo ""
    echo "Updating README..."
    
    local pascal_name=$(to_pascal_case "$PLUGIN_NAME")
    
    cat > "$PROJECT_ROOT/README.md" << README_EOF
# OpenProject ${pascal_name} Plugin

TODO: Add description of your plugin.

## Installation

Add this plugin to your OpenProject installation by adding the following to \`Gemfile.plugins\`:

\`\`\`ruby
group :opf_plugins do
  gem 'openproject-$PLUGIN_NAME', git: 'https://github.com/your-org/openproject-$PLUGIN_NAME.git', branch: 'main'
end
\`\`\`

Then run:

\`\`\`bash
./bin/setup_dev
bundle exec rails db:migrate
\`\`\`

## Development

### Prerequisites

- OpenProject development environment ([setup guide](https://www.openproject.org/docs/development/development-environment-docker/))
- Ruby version matching OpenProject core

### Local Development

1. Clone this repository alongside your OpenProject core installation
2. Add to \`Gemfile.plugins\`:

\`\`\`ruby
group :opf_plugins do
  gem 'openproject-$PLUGIN_NAME', path: '../openproject-$PLUGIN_NAME'
end
\`\`\`

3. Run \`./bin/setup_dev\` from OpenProject core
4. Start development server: \`./bin/rails server\`

### Configure SonarQube

The SonarQube workflow needs a SonarQube project key stored as a GitHub repository variable. Use [Bayer SonarQube](https://docs.int.bayer.com/cloud/devops/sonarqube/) at **https://sonar.cloud.bayer.com** and follow these steps:

1. **Create a new project** — In [SonarQube](https://sonar.cloud.bayer.com), create a new project. See [Creating your project](https://docs.sonarsource.com/sonarqube-server/project-administration/creating-your-project) for guidance.

2. **Add the GitHub repository to the project** — Associate your plugin's GitHub repo with the SonarQube project (e.g. via GitHub integration or import). See [Importing GitHub repositories](https://docs.sonarsource.com/sonarqube-server/devops-platform-integration/github-integration/importing-github-repositories).

3. **Find the project key** — The project key is shown in the project's settings or on the project homepage in SonarQube. Copy this value. See [Changing the project key](https://docs.sonarsource.com/sonarqube-server/project-administration/maintaining-project/changing-project-key) for where it appears.

4. **Add the variable in GitHub** — Open your repository's Actions variables page:

   **https://github.com/YOUR_ORG/YOUR_REPO/settings/actions**

   Open the **Variables** tab, then add a new repository variable:

   - **Name** (copy exactly):

     \`\`\`
     FAWKES_SONAR_PROJECT_KEY
     \`\`\`

   - **Value:** the SonarQube project key from step 3.

That's it! The reusable workflow automatically uses the project key from your repository variable.

> **Note:** This README is focused on the template and initial setup. Once you've completed the steps above (including SonarQube configuration), you may want to trim or adapt it for your plugin—for example, the SonarQube section is only relevant until you've done it and can be removed or shortened afterward.

### Running Tests

From the OpenProject core directory:

\`\`\`bash
RAILS_ENV=test bundle exec rspec \$(bundle show openproject-$PLUGIN_NAME)/spec
\`\`\`

## License

GPLv3 - See LICENSE file for details.
README_EOF
    
    print_success "Updated README.md"
}

# Self-cleanup
self_cleanup() {
    echo ""
    echo "Cleaning up setup scripts..."
    
    # Remove test script if it exists
    if [[ -f "$SCRIPT_DIR/test-setup.sh" ]]; then
        rm -f "$SCRIPT_DIR/test-setup.sh"
        print_success "Removed scripts/test-setup.sh"
    fi
    
    # Remove this script
    rm -f "$SCRIPT_DIR/setup-plugin.sh"
    print_success "Removed scripts/setup-plugin.sh"
    
    # Remove scripts directory if empty
    rmdir "$SCRIPT_DIR" 2>/dev/null || true
}

# Print summary
print_summary() {
    local pascal_name=$(to_pascal_case "$PLUGIN_NAME")
    
    echo ""
    echo "============================================"
    echo -e "${GREEN}Plugin setup complete!${NC}"
    echo "============================================"
    echo ""
    echo "Plugin: openproject-$PLUGIN_NAME"
    echo "Module: OpenProject::$pascal_name"
    echo ""
    echo "Next steps:"
    echo "  1. Update gemspec with your author info"
    echo "  2. Configure SonarQube and add FAWKES_SONAR_PROJECT_KEY (see README § Configure SonarQube)"
    echo "  3. Commit and push your changes"
    echo ""
    echo "To add this plugin to OpenProject:"
    echo ""
    echo "  group :opf_plugins do"
    echo "    gem 'openproject-$PLUGIN_NAME', path: '../openproject-$PLUGIN_NAME'"
    echo "  end"
    echo ""
}

# Main execution
main() {
    echo "=========================================="
    echo "OpenProject Plugin Setup"
    echo "=========================================="
    
    parse_args "$@"
    validate_plugin_name "$PLUGIN_NAME"
    check_already_run
    
    local pascal_name=$(to_pascal_case "$PLUGIN_NAME")
    
    echo ""
    echo "Plugin name: $PLUGIN_NAME"
    echo "Module name: $pascal_name"
    echo "Clean mode:  $CLEAN_MODE"
    
    cd "$PROJECT_ROOT"
    
    rename_directories
    rename_files
    replace_content
    create_sonarqube_config
    
    if [[ "$CLEAN_MODE" == "true" ]]; then
        clean_examples
    fi
    
    update_readme
    self_cleanup
    print_summary
}

main "$@"
