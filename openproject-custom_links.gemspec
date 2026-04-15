# encoding: UTF-8
$:.push File.expand_path("../lib", __FILE__)
$:.push File.expand_path("../../lib", __dir__)

require 'open_project/custom_links/version'
# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "openproject-custom_links"
  s.version     = OpenProject::CustomLinks::VERSION
  s.authors     = "Vignesh Madhavan"
  s.email       = "vignesh.madhavan.ext@bayer.com "
  s.homepage    = "https://community.openproject.org/projects/proto-plugin"  # TODO check this URL
  s.summary     = 'OpenProject Custom links'
  s.description = "A prototype to enable additional relationships and attachments"
  s.license     = "GPLv3"

  s.files = Dir["{app,config,db,lib}/**/*"] + %w(CHANGELOG.md README.md)
end
