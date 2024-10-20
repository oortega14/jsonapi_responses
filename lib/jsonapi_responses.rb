require_relative 'jsonapi_responses/version'
require 'rails'

module JsonapiResponses
  # Classes
  class Engine < ::Rails::Engine
    isolate_namespace JsonapiResponses

    initializer 'jsonapi_responses.initialize' do
      ActiveSupport.on_load(:action_controller_base) do
        include JsonapiResponses::Respondable
      end
    end
  end

  class Error < StandardError; end
end
