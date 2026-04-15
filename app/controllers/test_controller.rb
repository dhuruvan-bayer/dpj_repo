class TestController < ApplicationController
  # Check for the permissions of the user
  # as defined in the engine.rb permissions block
  before_action :find_project_by_project_id
  before_action :authorize

  def index
    render layout: true
  end

  private

  # def notify_changed_kittens(action, changed_kitten)
  #   OpenProject::Notifications.send(:kittens_changed, action: action, kitten: changed_kitten)
  # end
end
