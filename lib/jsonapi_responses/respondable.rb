require 'active_support/concern'
require 'jsonapi_responses/serializable'
require 'jsonapi_responses/user_context_provider'

module JsonapiResponses
  # Respondable module
  module Respondable
    extend ActiveSupport::Concern
    include JsonapiResponses::Serializable
    include JsonapiResponses::UserContextProvider

    private

    def render_with(record, options = {})
      action = options[:action] || action_name.to_sym
      context = (options[:context] || {}).merge(serialization_user)
      context = context.merge(view: params[:view]&.to_sym) if context.key?(:view)
      serializer_class = "#{controller_name.singularize.camelize}Serializer".constantize
      send("respond_for_#{action}", record, serializer_class, context)
    rescue NoMethodError
      render_invalid_action
    end

    def respond_for_index(record, serializer_class, context)
      render json: serialize_collection(record, serializer_class, context)
    end

    def respond_for_show(record, serializer_class, context)
      render json: serialize_item(record, serializer_class, context)
    end

    def respond_for_create(record, serializer_class, context)
      if record.save
        render json: serialize_item(record, serializer_class, context), status: :created
      else
        render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def respond_for_update(record, serializer_class, context)
      if record.errors.empty?
        render json: serialize_item(record, serializer_class, context), status: :ok
      else
        render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def respond_for_destroy(record, _, _)
      if record.destroy
        render json: { message: 'register destroyed successfully' }, status: :ok
      else
        render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def render_invalid_action
      render json: { message: 'Action not supported' }, status: :bad_request
    end
  end
end
