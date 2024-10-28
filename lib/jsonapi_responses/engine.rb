# lib/jsonapi_responses/engine.rb
require 'active_support'
require 'rails'

module JsonapiResponses
  # Define Engine
  class Engine < ::Rails::Engine
    isolate_namespace JsonapiResponses
  end
end
