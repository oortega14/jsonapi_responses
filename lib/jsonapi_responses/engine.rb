# lib/jsonapi_responses/engine.rb
require 'active_support'
module JsonapiResponses
  # Define Engine
  class Engine < ::Rails::Engine
    isolate_namespace JsonapiResponses

    initializer 'jsonapi_responses.initialize' do
      Rails.application.config.to_prepare do
        ApplicationController.include JsonapiResponses::Respondable
      end
    end
  end
end
