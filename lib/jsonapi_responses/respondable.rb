require 'active_support/concern'
require 'jsonapi_responses/serializable'
require 'jsonapi_responses/user_context_provider'
require 'jsonapi_responses/responder'

module JsonapiResponses
  # Respondable module
  module Respondable
    extend ActiveSupport::Concern
    include JsonapiResponses::Serializable
    include JsonapiResponses::UserContextProvider

    included do
      class_attribute :custom_action_mappings, default: {}
      class_attribute :response_definitions, default: {}
    end

    class_methods do
      # Configure custom action mappings
      # Example: map_response_action :public_index, to: :index
      #          map_response_action :export_csv, to: :custom_export
      def map_response_action(action_name, options = {})
        self.custom_action_mappings = custom_action_mappings.merge(
          action_name.to_sym => options[:to].to_sym
        )
      end

      # Configure multiple action mappings at once
      # Example: map_response_actions public_index: :index, export_csv: :custom_export
      def map_response_actions(mappings = {})
        self.custom_action_mappings = custom_action_mappings.merge(
          mappings.transform_keys(&:to_sym).transform_values(&:to_sym)
        )
      end

      # Define response behavior using metaprogramming
      # Example: 
      #   define_response_for :dashboard do |record, serializer_class, context|
      #     render json: { data: serialize_item(record, serializer_class, context) }
      #   end
      def define_response_for(action_name, &block)
        action_sym = action_name.to_sym
        method_name = "respond_for_#{action_sym}"
        
        # Store the block for potential inspection/debugging
        self.response_definitions = response_definitions.merge(action_sym => block)
        
        # Define the method dynamically
        define_method(method_name, &block)
        
        # Make it private since all respond_for_* methods should be private
        private method_name
      end

      # Batch define multiple responses with same pattern
      # Example:
      #   define_responses_for [:public_index, :admin_index] do |record, serializer_class, context|
      #     render json: { data: serialize_collection(record, serializer_class, context) }
      #   end
      def define_responses_for(action_names, &block)
        action_names.each do |action_name|
          define_response_for(action_name, &block)
        end
      end

      # Define common CRUD-like responses with customizable behavior
      # Example:
      #   define_crud_responses(
      #     list_actions: [:index, :public_index, :admin_index],
      #     show_actions: [:show, :public_show, :preview],
      #     collection_context: -> { { meta: { total: @records.count } } },
      #     item_context: -> { { meta: { access_level: 'public' } } }
      #   )
      def define_crud_responses(options = {})
        list_actions = options[:list_actions] || []
        show_actions = options[:show_actions] || []
        collection_context_proc = options[:collection_context]
        item_context_proc = options[:item_context]

        # Define list-type responses
        list_actions.each do |action|
          define_response_for action do |record, serializer_class, context|
            enhanced_context = context.dup
            if collection_context_proc
              additional_context = instance_eval(&collection_context_proc)
              enhanced_context.merge!(additional_context) if additional_context.is_a?(Hash)
            end
            
            render json: serialize_collection(record, serializer_class, enhanced_context)
          end
        end

        # Define show-type responses  
        show_actions.each do |action|
          define_response_for action do |record, serializer_class, context|
            enhanced_context = context.dup
            if item_context_proc
              additional_context = instance_eval(&item_context_proc)
              enhanced_context.merge!(additional_context) if additional_context.is_a?(Hash)
            end
            
            render json: serialize_item(record, serializer_class, enhanced_context)
          end
        end
      end

      # Helper to generate standard REST-like responses with custom naming
      # Example:
      #   generate_rest_responses(
      #     namespace: 'public',
      #     actions: [:index, :show],
      #     context: { access_level: 'public' }
      #   )
      def generate_rest_responses(options = {})
        namespace = options[:namespace]
        actions = options[:actions] || [:index, :show, :create, :update, :destroy]
        base_context = options[:context] || {}

        actions.each do |base_action|
          action_name = namespace ? "#{namespace}_#{base_action}" : base_action
          
          define_response_for action_name do |record, serializer_class, context|
            enhanced_context = base_context.merge(context)
            
            # Delegate to the base action's response method if it exists
            base_method = "respond_for_#{base_action}"
            if respond_to?(base_method, true)
              send(base_method, record, serializer_class, enhanced_context)
            else
              # Fallback to appropriate default behavior
              case base_action.to_sym
              when :index
                render json: serialize_collection(record, serializer_class, enhanced_context)
              when :show
                render json: serialize_item(record, serializer_class, enhanced_context)
              when :create
                if record.save
                  render json: serialize_item(record, serializer_class, enhanced_context), status: :created
                else
                  render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
                end
              when :update
                if record.errors.empty?
                  render json: serialize_item(record, serializer_class, enhanced_context), status: :ok
                else
                  render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
                end
              when :destroy
                if record.destroy
                  render json: { message: 'Record deleted successfully' }, status: :ok
                else
                  render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
                end
              else
                render json: { error: "No default behavior for action #{base_action}" }, status: :not_implemented
              end
            end
          end
        end
      end
    end

    private

    def render_with(record, options = {})
      action = options[:action] || action_name.to_sym
      context = (options[:context] || {}).merge(serialization_user)
      # Only use params[:view] if view is not already provided in context
      context[:view] ||= params[:view]&.to_sym
      serializer_class = options[:serializer] || "#{controller_name.singularize.camelize}Serializer".constantize
      
      # If a custom responder is provided, use it
      if options[:responder]
        responder_class = options[:responder]
        responder = responder_class.new(self, record, serializer_class, context)
        
        # If an action method is specified, call it on the responder
        if options[:action] && responder.respond_to?(options[:action])
          return responder.public_send(options[:action])
        end
        
        # Otherwise call the default render method
        return responder.render
      end
      
      # Find the appropriate response method
      response_method = find_response_method_for_action(action)
      send(response_method, record, serializer_class, context)
    rescue NoMethodError => e
      # If no method found, provide helpful error message
      if e.message.include?("respond_for_")
        render_invalid_action(action)
      else
        raise e
      end
    end

    def find_response_method_for_action(action)
      # 1. Check if controller has a custom response method defined
      custom_method = "respond_for_#{action}"
      return custom_method if respond_to?(custom_method, true)

      # 2. Check if action is mapped to another action via configuration
      mapped_action = custom_action_mappings[action]
      if mapped_action
        mapped_method = "respond_for_#{mapped_action}"
        return mapped_method if respond_to?(mapped_method, true)
      end

      # 3. If no custom method or mapping found, return the expected method name
      # This will raise NoMethodError with a clear message about what's missing
      "respond_for_#{action}"
    end

    def respond_for_index(record, serializer_class, context)
      response = { data: serialize_collection(record, serializer_class, context) }
      
      # Auto-detect pagination and add meta if available
      if paginated?(record)
        response[:meta] = pagination_meta(record, context)
      elsif context[:meta]
        # Allow manual meta from context
        response[:meta] = context[:meta]
      end
      
      render json: response
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

    def render_invalid_action(action = nil)
      action_name = action || action_name
      render json: { 
        error: "Action not supported",
        message: "The action '#{action_name}' is not supported by this controller",
        details: {
          action: action_name,
          controller: controller_name,
          required_method: "respond_for_#{action_name}"
        },
        suggestions: [
          "Define a 'respond_for_#{action_name}' method in your controller",
          "Use 'map_response_action :#{action_name}, to: :existing_action' to map it to an existing response method"
        ]
      }, status: :bad_request
    end

    # Check if record is paginated (Kaminari or WillPaginate support)
    def paginated?(record)
      record.respond_to?(:current_page) && 
      record.respond_to?(:total_pages) &&
      record.respond_to?(:total_count)
    end

    # Extract pagination metadata from paginated record
    def pagination_meta(record, context = {})
      base_meta = {
        current_page: record.current_page,
        total_pages: record.total_pages,
        total_count: record.total_count,
        per_page: record.try(:limit_value) || record.try(:per_page) || context[:per_page]
      }.compact
      
      # Merge with any additional meta from context
      context[:meta] ? base_meta.merge(context[:meta]) : base_meta
    end
  end
end
