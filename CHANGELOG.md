<!---- copyright
OpenProject Plugins Plugin

Copyright (C) 2013 - 2014 the OpenProject Foundation (OPF)

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License version 3.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

See doc/COPYRIGHT.md for more details.

++-->

# Changelog

All notable changes to the OpenProject DsoOs Plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [7.1.0] - 2026-04-15

### Added
- **Version-Wiki Page API**
  - Custom `GET /api/v3/projects/:project_identifier/wiki_pages` endpoint
  - Returns only wiki pages whose title matches the `wiki_page_title` field of a project version
  - Embeds the linked version record directly into each wiki page response element
  - Paginated response with `offset` and `pageSize` query parameters (default 20, max 100)
  - Results ordered by wiki page `id`

- **API Architecture**
  - Endpoint mounted inside OpenProject's existing `API::V3::Workspaces::NestedApis` — no route conflicts with core
  - Inherits project resolution, visibility scoping, and admin bypass from `ProjectsAPI`'s `after_validation` block
  - Graceful 404 with descriptive message when project has no wiki

- **Plugin Infrastructure**
  - Rails engine with OpenProject plugin registration
  - Homescreen block support via `OpenProject::Static::Homescreen`
  - Hook listener (`Hooks`) ready for view and controller extension points
  - User invitation notification subscriber via `OpenProject::Notifications`

### Technical Implementation
- **Route Integration**: Uses `add_api_endpoint "API::V3::Workspaces::NestedApis"` to inject into the existing project route tree, following the same pattern as `VersionsByProjectAPI` and `CategoriesByWorkspaceAPI`
- **Project Lookup**: Delegates entirely to `ProjectsAPI` — supports both numeric ID and string identifier, respects `Project.visible(current_user)` scoping
- **Pagination**: 1-based `offset` / `pageSize` convention consistent with OpenProject API v3

## [0.1.0] - Initial Development

### Added
- Initial plugin structure and scaffolding
- Basic engine and hook setup
- Development environment configuration
