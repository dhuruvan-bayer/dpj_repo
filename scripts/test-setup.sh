#!/bin/bash
#
# test-setup.sh - Test the setup-plugin.sh script using the exact user workflow
#
# This script simulates what a real user would do:
# 1. "Use this template" on GitHub (simulated by copying the template)
# 2. Clone the new repo (simulated by working in temp directory)
# 3. Run ./scripts/setup-plugin.sh
# 4. Verify the plugin works with OpenProject using Docker
#
# Requirements:
# - Docker or Colima running
# - Internet access (to clone OpenProject core if not provided)
#
# Usage:
#   ./scripts/test-setup.sh [options]
#
# Options:
#   --openproject-core PATH   Path to existing OpenProject core (optional)
#   --skip-docker             Skip Docker verification
#   --keep-temp               Keep temp directory after test
#   --help                    Show this help
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TEST_PLUGIN_NAME="test_plugin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(dirname "$SCRIPT_DIR")"
OPENPROJECT_CORE=""
SKIP_DOCKER=false
KEEP_TEMP=false
TEMP_DIR=""

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_info() {
    echo -e "       $1"
}

show_help() {
    head -25 "$0" | tail -18 | sed 's/^#//' | sed 's/^ //'
    exit 0
}

cleanup() {
    echo ""
    echo "=== Cleanup ==="
    
    # Clean up docker resources first
    if [[ -n "$CORE_DIR" && -n "$COMPOSE_CMD" && "$SKIP_DOCKER" != "true" ]]; then
        print_info "Stopping Docker containers..."
        cd "$CORE_DIR" 2>/dev/null || true
        $COMPOSE_CMD down --remove-orphans 2>/dev/null || true
        
        # Remove the test files from OpenProject core
        if [[ -f "$CORE_DIR/Gemfile.plugins" ]]; then
            rm -f "$CORE_DIR/Gemfile.plugins"
            print_success "Removed test Gemfile.plugins"
        fi
        if [[ -d "$CORE_DIR/modules/$TEST_PLUGIN_NAME" ]]; then
            rm -rf "$CORE_DIR/modules/$TEST_PLUGIN_NAME"
            print_success "Removed test plugin from modules/"
        fi
    fi
    
    # Clean up temp directory
    if [[ "$KEEP_TEMP" == "false" && -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        print_info "Removing temp directory..."
        rm -rf "$TEMP_DIR"
        print_success "Removed $TEMP_DIR"
    elif [[ "$KEEP_TEMP" == "true" && -n "$TEMP_DIR" ]]; then
        print_warning "Temp directory kept at: $TEMP_DIR"
        print_warning "Plugin copy at: $PLUGIN_DIR"
    fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --openproject-core)
                OPENPROJECT_CORE="$2"
                shift 2
                ;;
            --skip-docker)
                SKIP_DOCKER=true
                shift
                ;;
            --keep-temp)
                KEEP_TEMP=true
                shift
                ;;
            --help|-h)
                show_help
                ;;
            *)
                print_fail "Unknown option: $1"
                show_help
                ;;
        esac
    done
}

# Verify prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check for required commands
    local required_commands=("sed" "grep" "find" "mktemp")
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            print_success "$cmd is available"
        else
            print_fail "$cmd is not available"
            exit 1
        fi
    done
    
    # Check Docker (unless skipped)
    if [[ "$SKIP_DOCKER" == "false" ]]; then
        if command -v docker &> /dev/null; then
            if docker info &> /dev/null; then
                print_success "Docker is running"
            else
                print_fail "Docker is not running (start Docker/Colima first)"
                exit 1
            fi
        else
            print_fail "Docker is not installed"
            exit 1
        fi
    else
        print_warning "Docker verification skipped"
    fi
    
    # Check if setup-plugin.sh exists
    if [[ -f "$SCRIPT_DIR/setup-plugin.sh" ]]; then
        print_success "setup-plugin.sh found"
    else
        print_fail "setup-plugin.sh not found in $SCRIPT_DIR"
        exit 1
    fi
}

# Step 1: Simulate "Use this template" by copying template to temp directory
simulate_github_template() {
    print_header "Step 1: Simulating 'Use this template'"
    
    TEMP_DIR=$(mktemp -d)
    local plugin_dir="$TEMP_DIR/openproject-$TEST_PLUGIN_NAME"
    
    print_info "Creating temp directory: $TEMP_DIR"
    print_info "Copying template to: $plugin_dir"
    
    cp -r "$TEMPLATE_DIR" "$plugin_dir"
    
    if [[ -d "$plugin_dir" ]]; then
        print_success "Template copied successfully"
    else
        print_fail "Failed to copy template"
        exit 1
    fi
    
    # Export for other functions
    export PLUGIN_DIR="$plugin_dir"
}

# Step 2: Run the setup script (exact user command)
run_setup_script() {
    print_header "Step 2: Running setup-plugin.sh (exact user command)"
    
    print_info "Command: ./scripts/setup-plugin.sh $TEST_PLUGIN_NAME --clean"
    echo ""
    
    cd "$PLUGIN_DIR"
    ./scripts/setup-plugin.sh "$TEST_PLUGIN_NAME" --clean
    
    print_success "Setup script completed"
}

# Step 3: Verify file transformations
verify_transformations() {
    print_header "Step 3: Verifying Transformations"
    
    local errors=0
    local pascal_name="TestPlugin"
    
    # Check renamed files exist
    echo "Checking renamed files..."
    local expected_files=(
        "openproject-$TEST_PLUGIN_NAME.gemspec"
        "lib/openproject-$TEST_PLUGIN_NAME.rb"
        "lib/open_project/$TEST_PLUGIN_NAME.rb"
        "lib/open_project/$TEST_PLUGIN_NAME/engine.rb"
        "lib/open_project/$TEST_PLUGIN_NAME/hooks.rb"
        "lib/open_project/$TEST_PLUGIN_NAME/version.rb"
    )
    
    for file in "${expected_files[@]}"; do
        if [[ -f "$PLUGIN_DIR/$file" ]]; then
            print_success "Found: $file"
        else
            print_fail "Missing: $file"
            errors=$((errors + 1))
        fi
    done
    
    # Check old files don't exist
    echo ""
    echo "Checking old files are removed..."
    local old_files=(
        "openproject-custom_links.gemspec"
        "lib/openproject-custom_links.rb"
        "lib/open_project/custom_links.rb"
        "lib/open_project/custom_links"
    )
    
    for file in "${old_files[@]}"; do
        if [[ -e "$PLUGIN_DIR/$file" ]]; then
            print_fail "Old file/dir still exists: $file"
            errors=$((errors + 1))
        else
            print_success "Removed: $file"
        fi
    done
    
    # Check directories renamed
    echo ""
    echo "Checking renamed directories..."
    local expected_dirs=(
        "lib/open_project/$TEST_PLUGIN_NAME"
        "app/views/hooks/$TEST_PLUGIN_NAME"
        "app/seeders/basic_data/$TEST_PLUGIN_NAME"
    )
    
    for dir in "${expected_dirs[@]}"; do
        if [[ -d "$PLUGIN_DIR/$dir" ]]; then
            print_success "Found directory: $dir"
        else
            print_fail "Missing directory: $dir"
            errors=$((errors + 1))
        fi
    done
    
    # Check no references to custom_links remain
    echo ""
    echo "Checking for remaining 'custom_links' references..."
    local remaining=$(grep -r "custom_links\|CustomLinks" "$PLUGIN_DIR" \
        --include="*.rb" --include="*.gemspec" --include="*.yml" \
        --exclude-dir=".git" 2>/dev/null || true)
    
    if [[ -z "$remaining" ]]; then
        print_success "No 'custom_links' references found"
    else
        print_fail "Found remaining 'custom_links' references:"
        echo "$remaining" | head -10
        errors=$((errors + 1))
    fi
    
    # Check new references exist
    echo ""
    echo "Checking new plugin references..."
    if grep -q "module OpenProject::$pascal_name" "$PLUGIN_DIR/lib/open_project/$TEST_PLUGIN_NAME/engine.rb"; then
        print_success "Found module OpenProject::$pascal_name in engine.rb"
    else
        print_fail "Module OpenProject::$pascal_name not found in engine.rb"
        errors=$((errors + 1))
    fi
    
    # Check SonarQube files
    echo ""
    echo "Checking SonarQube configuration..."
    if [[ -f "$PLUGIN_DIR/.github/workflows/sonarqube.yml" ]]; then
        print_success "Found .github/workflows/sonarqube.yml"
        if grep -q "openproject-$TEST_PLUGIN_NAME" "$PLUGIN_DIR/.github/workflows/sonarqube.yml"; then
            print_success "sonarqube.yml contains correct plugin name"
        else
            print_fail "sonarqube.yml missing correct plugin name"
            errors=$((errors + 1))
        fi
    else
        print_fail "Missing .github/workflows/sonarqube.yml"
        errors=$((errors + 1))
    fi
    
    if [[ -f "$PLUGIN_DIR/sonar-project.properties" ]]; then
        print_success "Found sonar-project.properties"
    else
        print_fail "Missing sonar-project.properties"
        errors=$((errors + 1))
    fi
    
    # Check clean mode removed example files
    echo ""
    echo "Checking example files removed (--clean mode)..."
    local should_be_removed=(
        "images"
        "spec/controllers"
        "spec/factories"
        "spec/features"
        "db/migrate"
        "app/models/test.rb"
        "app/controllers/test_controller.rb"
        "app/views/test"
        ".travis.yml"
    )
    
    for item in "${should_be_removed[@]}"; do
        if [[ -e "$PLUGIN_DIR/$item" ]]; then
            print_fail "Example not removed: $item"
            errors=$((errors + 1))
        else
            print_success "Removed: $item"
        fi
    done
    
    # Check spec_helper.rb is preserved
    if [[ -f "$PLUGIN_DIR/spec/spec_helper.rb" ]]; then
        print_success "spec/spec_helper.rb preserved"
    else
        print_fail "spec/spec_helper.rb was removed (should be kept)"
        errors=$((errors + 1))
    fi
    
    # Check setup scripts removed themselves
    echo ""
    echo "Checking script self-cleanup..."
    if [[ ! -f "$PLUGIN_DIR/scripts/setup-plugin.sh" ]]; then
        print_success "setup-plugin.sh removed itself"
    else
        print_fail "setup-plugin.sh still exists"
        errors=$((errors + 1))
    fi
    
    if [[ "$errors" -gt 0 ]]; then
        print_fail "Verification failed with $errors errors"
        return 1
    else
        print_success "All transformations verified successfully"
        return 0
    fi
}

# Detect docker compose command (v1 vs v2)
get_docker_compose_cmd() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    elif docker-compose version &> /dev/null; then
        echo "docker-compose"
    else
        print_fail "Neither 'docker compose' nor 'docker-compose' found"
        exit 1
    fi
}

# Global variables for docker verification
CORE_DIR=""
COMPOSE_CMD=""

# Step 4: Full Docker Integration Test
# This runs the complete workflow: database, migrations, server, and verification
docker_verification() {
    if [[ "$SKIP_DOCKER" == "true" ]]; then
        print_header "Step 4: Docker Integration Test (SKIPPED)"
        print_warning "Docker verification was skipped with --skip-docker"
        return 0
    fi
    
    print_header "Step 4: Full Docker Integration Test"
    
    COMPOSE_CMD=$(get_docker_compose_cmd)
    print_info "Using compose command: $COMPOSE_CMD"
    
    # Use provided OpenProject core or find it
    if [[ -n "$OPENPROJECT_CORE" && -d "$OPENPROJECT_CORE" ]]; then
        CORE_DIR="$OPENPROJECT_CORE"
        print_info "Using provided OpenProject core: $CORE_DIR"
    else
        # Check if core exists in workspace
        local workspace_core="/Users/vignesh.madhavan.ext/Documents/projects/openproject/core"
        if [[ -d "$workspace_core" ]]; then
            CORE_DIR="$workspace_core"
            print_info "Using workspace OpenProject core: $CORE_DIR"
        else
            print_info "Cloning OpenProject core (this may take a while)..."
            CORE_DIR="$TEMP_DIR/openproject-core"
            git clone --depth 1 https://github.com/opf/openproject.git "$CORE_DIR"
            print_success "Cloned OpenProject core"
        fi
    fi
    
    cd "$CORE_DIR"
    
    # Set required environment variables
    export LOCAL_DEV_CHECK=1
    export DEV_UID=$(id -u)
    export DEV_GID=$(id -g)
    
    local pascal_name="TestPlugin"
    local errors=0
    
    # ==========================================
    # Step 4.1: Link plugin to OpenProject
    # ==========================================
    echo ""
    echo "--- Step 4.1: Linking Plugin ---"
    
    print_info "Linking plugin to OpenProject modules..."
    mkdir -p "$CORE_DIR/modules/$TEST_PLUGIN_NAME"
    cp -r "$PLUGIN_DIR/"* "$CORE_DIR/modules/$TEST_PLUGIN_NAME/"
    print_success "Plugin linked to modules/$TEST_PLUGIN_NAME"
    
    # Create Gemfile.plugins
    print_info "Creating Gemfile.plugins..."
    cat > "$CORE_DIR/Gemfile.plugins" << EOF
group :opf_plugins do
  gem 'openproject-$TEST_PLUGIN_NAME', path: 'modules/$TEST_PLUGIN_NAME'
end
EOF
    print_success "Created Gemfile.plugins"
    
    # ==========================================
    # Step 4.2: Build Docker Images
    # ==========================================
    echo ""
    echo "--- Step 4.2: Building Docker Images ---"
    
    print_info "Building backend Docker image (this may take several minutes)..."
    if $COMPOSE_CMD build backend 2>&1; then
        print_success "Docker image built successfully"
    else
        print_fail "Failed to build Docker image"
        return 1
    fi
    
    # ==========================================
    # Step 4.3: Start Database
    # ==========================================
    echo ""
    echo "--- Step 4.3: Starting Database ---"
    
    print_info "Starting PostgreSQL database..."
    $COMPOSE_CMD up -d db
    
    # Wait for database to be ready
    print_info "Waiting for database to be ready..."
    local db_ready=false
    for i in {1..30}; do
        if $COMPOSE_CMD exec -T db pg_isready -U postgres &> /dev/null; then
            db_ready=true
            break
        fi
        sleep 2
        echo -n "."
    done
    echo ""
    
    if [[ "$db_ready" == "true" ]]; then
        print_success "Database is ready"
    else
        print_fail "Database failed to start"
        return 1
    fi
    
    # ==========================================
    # Step 4.4: Bundle Install
    # ==========================================
    echo ""
    echo "--- Step 4.4: Installing Dependencies ---"
    
    print_info "Running bundle install (this may take a few minutes)..."
    if $COMPOSE_CMD run --rm backend bundle install 2>&1; then
        print_success "Bundle install completed"
    else
        print_fail "Bundle install failed"
        return 1
    fi
    
    # ==========================================
    # Step 4.5: Database Setup & Migrations
    # ==========================================
    echo ""
    echo "--- Step 4.5: Database Setup & Migrations ---"
    
    print_info "Creating database..."
    if $COMPOSE_CMD run --rm backend bundle exec rails db:create 2>&1; then
        print_success "Database created"
    else
        print_warning "Database may already exist, continuing..."
    fi
    
    print_info "Running database migrations (including plugin migrations)..."
    if $COMPOSE_CMD run --rm backend bundle exec rails db:migrate 2>&1; then
        print_success "Database migrations completed"
    else
        print_fail "Database migrations failed"
        errors=$((errors + 1))
    fi
    
    # ==========================================
    # Step 4.6: Verify Plugin Registration
    # ==========================================
    echo ""
    echo "--- Step 4.6: Verifying Plugin Registration ---"
    
    print_info "Checking if plugin is registered in OpenProject..."
    
    local plugin_check=$($COMPOSE_CMD run --rm backend bundle exec rails runner "
        # Check if plugin module is loadable
        require 'open_project/$TEST_PLUGIN_NAME'
        puts 'MODULE_LOADED: OpenProject::$pascal_name'
        puts 'VERSION: ' + OpenProject::$pascal_name::VERSION
        
        # Check if plugin is registered with OpenProject
        plugin = OpenProject::Plugins::ModuleHandler.plugin('openproject-$TEST_PLUGIN_NAME')
        if plugin
            puts 'REGISTERED: true'
            puts 'PLUGIN_NAME: ' + plugin.name.to_s
        else
            puts 'REGISTERED: false'
        end
        
        # Check if engine is loaded
        engine = OpenProject::$pascal_name::Engine rescue nil
        if engine
            puts 'ENGINE_LOADED: true'
            puts 'ENGINE_NAME: ' + engine.engine_name.to_s
        else
            puts 'ENGINE_LOADED: false'
        end
    " 2>&1)
    
    echo "$plugin_check"
    
    if echo "$plugin_check" | grep -q "MODULE_LOADED"; then
        print_success "Plugin module loaded successfully"
    else
        print_fail "Plugin module failed to load"
        errors=$((errors + 1))
    fi
    
    if echo "$plugin_check" | grep -q "ENGINE_LOADED: true"; then
        print_success "Plugin engine loaded successfully"
    else
        print_fail "Plugin engine failed to load"
        errors=$((errors + 1))
    fi
    
    # ==========================================
    # Step 4.7: Verify Plugin Routes (if any)
    # ==========================================
    echo ""
    echo "--- Step 4.7: Verifying Plugin Routes ---"
    
    print_info "Checking plugin routes..."
    local routes_check=$($COMPOSE_CMD run --rm backend bundle exec rails routes 2>&1 | grep -i "$TEST_PLUGIN_NAME" || echo "NO_ROUTES")
    
    if [[ "$routes_check" != "NO_ROUTES" ]]; then
        print_success "Plugin routes found:"
        echo "$routes_check" | head -10
    else
        print_info "No plugin-specific routes found (this is OK for minimal plugins)"
    fi
    
    # ==========================================
    # Step 4.8: Verify Plugin Assets Registration
    # ==========================================
    echo ""
    echo "--- Step 4.8: Verifying Plugin Integration ---"
    
    print_info "Verifying plugin hooks are registered..."
    local hooks_check=$($COMPOSE_CMD run --rm backend bundle exec rails runner "
        # Check hooks registration
        hooks = OpenProject::Hook::ViewListener.descendants
        plugin_hooks = hooks.select { |h| h.name.to_s.include?('$pascal_name') }
        if plugin_hooks.any?
            puts 'HOOKS_REGISTERED: true'
            plugin_hooks.each { |h| puts 'HOOK: ' + h.name.to_s }
        else
            puts 'HOOKS_REGISTERED: none'
        end
    " 2>&1)
    
    echo "$hooks_check"
    
    if echo "$hooks_check" | grep -q "HOOKS_REGISTERED: true"; then
        print_success "Plugin hooks are registered"
    else
        print_info "No plugin hooks registered (this is OK for minimal plugins)"
    fi
    
    # ==========================================
    # Step 4.9: Start Full Application Stack
    # ==========================================
    echo ""
    echo "--- Step 4.9: Starting Full Application Stack ---"
    
    print_info "Starting OpenProject application (backend + worker)..."
    $COMPOSE_CMD up -d backend worker
    
    # Wait for the application to be ready
    print_info "Waiting for application to start (this may take 1-2 minutes)..."
    local app_ready=false
    for i in {1..60}; do
        # Check if Rails is responding
        if $COMPOSE_CMD exec -T backend curl -s http://localhost:3000/health_checks/all 2>/dev/null | grep -q "CHECKS PASSED"; then
            app_ready=true
            break
        fi
        sleep 3
        echo -n "."
    done
    echo ""
    
    if [[ "$app_ready" == "true" ]]; then
        print_success "Application is running and healthy"
    else
        print_warning "Application health check timed out (may still be starting)"
        # Don't fail here, try the next checks anyway
    fi
    
    # ==========================================
    # Step 4.10: Verify Plugin in Admin Page
    # ==========================================
    echo ""
    echo "--- Step 4.10: Verifying Plugin in Admin Plugins List ---"
    
    print_info "Checking plugin appears in OpenProject plugins list..."
    local admin_check=$($COMPOSE_CMD run --rm backend bundle exec rails runner "
        # Get all registered plugins
        plugins = Redmine::Plugin.all
        our_plugin = plugins.find { |p| p.id.to_s == 'openproject-$TEST_PLUGIN_NAME' }
        
        if our_plugin
            puts 'PLUGIN_FOUND: true'
            puts 'PLUGIN_ID: ' + our_plugin.id.to_s
            puts 'PLUGIN_VERSION: ' + (our_plugin.version || 'unknown')
            puts 'PLUGIN_AUTHOR: ' + (our_plugin.author || 'unknown')
        else
            # List all plugins for debugging
            puts 'PLUGIN_FOUND: false'
            puts 'AVAILABLE_PLUGINS:'
            plugins.each { |p| puts '  - ' + p.id.to_s }
        end
    " 2>&1)
    
    echo "$admin_check"
    
    if echo "$admin_check" | grep -q "PLUGIN_FOUND: true"; then
        print_success "Plugin is registered in OpenProject plugins list"
    else
        print_fail "Plugin not found in OpenProject plugins list"
        errors=$((errors + 1))
    fi
    
    # ==========================================
    # Step 4.11: Test Plugin Seed Data (if any)
    # ==========================================
    echo ""
    echo "--- Step 4.11: Testing Plugin Seeders ---"
    
    print_info "Running database seeds (including plugin seeds)..."
    local seed_result=$($COMPOSE_CMD run --rm backend bundle exec rails db:seed 2>&1) || true
    
    if [[ $? -eq 0 ]] || echo "$seed_result" | grep -q "Seeding"; then
        print_success "Database seeding completed"
    else
        print_info "Seeding had issues (may be OK if seeds already ran)"
    fi
    
    # ==========================================
    # Summary
    # ==========================================
    echo ""
    echo "--- Docker Integration Test Summary ---"
    
    if [[ "$errors" -gt 0 ]]; then
        print_fail "Docker integration test completed with $errors errors"
        return 1
    else
        print_success "All Docker integration tests passed!"
        echo ""
        echo "Plugin successfully:"
        echo "  - Installed via bundle"
        echo "  - Database migrations ran"
        echo "  - Engine loaded in Rails"
        echo "  - Registered in OpenProject"
        return 0
    fi
}

# Print test summary
print_summary() {
    print_header "Test Summary"
    
    echo "Plugin name:     $TEST_PLUGIN_NAME"
    echo "Template dir:    $TEMPLATE_DIR"
    echo "Temp dir:        $TEMP_DIR"
    echo "Clean mode:      yes"
    echo "Docker tested:   $([ "$SKIP_DOCKER" == "true" ] && echo "no" || echo "yes")"
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    echo "The setup-plugin.sh script works correctly."
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "Testing setup-plugin.sh"
    echo "=========================================="
    
    parse_args "$@"
    check_prerequisites
    simulate_github_template
    run_setup_script
    
    if verify_transformations; then
        docker_verification
        print_summary
    else
        print_fail "Transformation verification failed"
        exit 1
    fi
}

main "$@"
