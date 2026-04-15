# encoding: UTF-8
$:.push File.expand_path("../lib", __FILE__)
$:.push File.expand_path("../../lib", __dir__)

require 'open_project/dso_os/version'
# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "openproject-dso_os"
  s.version     = OpenProject::DsoOs::VERSION
  s.authors     = "Your Name"
  s.email       = "your.email@example.com"
  s.homepage    = "https://github.com/your-org/openproject-dso_os"
  s.summary     = 'OpenProject DsoOs Plugin'
  s.description = "TODO: Add plugin description"
  s.license     = "GPLv3"

  s.files = Dir["{app,config,db,lib}/**/*"] + %w(CHANGELOG.md README.md)
end
