module API
  module V3
    module WikiPages
      class WikiPagesByProjectAPI < ::API::OpenProjectAPI
        resources :wiki_pages do
          get do
            project = @project

            wiki = project.wiki
            error!({ message: "This project has no wiki." }, 404) unless wiki

            ai_versions = project.versions
                                 .where.not(wiki_page_title: [nil, ""])

            # Build a lookup: wiki_page_title → version
            version_by_title = ai_versions.index_by(&:wiki_page_title)

            # Pagination params — follow OpenProject API v3 conventions
            page_size = (params[:pageSize] || 20).to_i.clamp(1, 100)
            offset    = (params[:offset]   ||  1).to_i.clamp(1, Float::INFINITY)
            sql_offset = (offset - 1) * page_size

            base_scope = wiki.pages.where(title: version_by_title.keys)
            total      = base_scope.count

            elements = base_scope
                         .order(:id)
                         .limit(page_size)
                         .offset(sql_offset)
                         .map do |page|
                           version = version_by_title[page.title]
                           page.as_json.merge("linked_version" => version.as_json)
                         end

            {
              "total"    => total,
              "count"    => elements.size,
              "pageSize" => page_size,
              "offset"   => offset,
              "data" => elements
            }
          end
        end
      end
    end
  end
end