require 'active_support/concern'

module JsonapiResponses
  # Serializable module
  module Serializable
    extend ActiveSupport::Concern

    def serialize_collection(collection, serializer_class, context = {})
      collection.map { |item| serialize_item(item, serializer_class, context) }
    end

    def serialize_item(item, serializer_class, context = {})
      serializer_class.new(item, context).serializable_hash
    end
  end
end
