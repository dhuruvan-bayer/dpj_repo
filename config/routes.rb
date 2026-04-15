Rails.application.routes.draw do
  scope '', as: 'kitten_plugin' do
    scope 'projects/:project_id', as: 'project' do
      resources :test
    end
  end
end
