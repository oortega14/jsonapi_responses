module JsonapiResponses
  # Base class for custom responders
  # Responders encapsulate response logic for custom actions,
  # keeping controllers clean and promoting reusability.
  #
  # @example Basic usage
  #   class FeaturedResponder < JsonapiResponses::Responder
  #     def render
  #       controller.render json: {
  #         data: serialize_collection(record),
  #         meta: {
  #           type: 'featured',
  #           count: record.count
  #         }
  #       }
  #     end
  #   end
  #
  # @example Using in controller
  #   def featured
  #     @academies = Academy.featured
  #     render_with(@academies, responder: FeaturedResponder)
  #   end
  class Responder
    attr_reader :controller, :record, :serializer_class, :context

    # @param controller [ActionController::Base] The controller instance
    # @param record [Object, Array, ActiveRecord::Relation] The record(s) to serialize
    # @param serializer_class [Class] The serializer class to use
    # @param context [Hash] Additional context for serialization
    def initialize(controller, record, serializer_class, context = {})
      @controller = controller
      @record = record
      @serializer_class = serializer_class
      @context = context
    end

    # Render the response. Must be implemented by subclasses.
    # @raise [NotImplementedError] if not implemented in subclass
    def render
      raise NotImplementedError, "#{self.class.name} must implement #render method"
    end

    protected

    # Serialize a collection of records
    # @param records [Array, ActiveRecord::Relation] Records to serialize
    # @param custom_serializer [Class, nil] Optional custom serializer
    # @param custom_context [Hash, nil] Optional custom context
    # @return [Array<Hash>] Serialized collection
    def serialize_collection(records = nil, custom_serializer = nil, custom_context = nil)
      records ||= record
      serializer = custom_serializer || serializer_class
      ctx = custom_context || context
      
      controller.send(:serialize_collection, records, serializer, ctx)
    end

    # Serialize a single record
    # @param item [Object] Record to serialize
    # @param custom_serializer [Class, nil] Optional custom serializer
    # @param custom_context [Hash, nil] Optional custom context
    # @return [Hash] Serialized record
    def serialize_item(item = nil, custom_serializer = nil, custom_context = nil)
      item ||= record
      serializer = custom_serializer || serializer_class
      ctx = custom_context || context
      
      controller.send(:serialize_item, item, serializer, ctx)
    end

    # Access to params from the controller
    # @return [ActionController::Parameters]
    def params
      controller.params
    end

    # Access to current_user from the controller (if available)
    # @return [Object, nil]
    def current_user
      controller.respond_to?(:current_user, true) ? controller.send(:current_user) : nil
    end

    # Helper to render JSON directly through the controller
    # @param data [Hash] Data to render
    # @param options [Hash] Additional render options (status, etc.)
    def render_json(data, options = {})
      controller.render({ json: data }.merge(options))
    end

    # Helper to check if record is a collection
    # @return [Boolean]
    def collection?
      record.is_a?(Array) || 
      record.is_a?(ActiveRecord::Relation) ||
      (record.respond_to?(:to_a) && !record.is_a?(Hash))
    end

    # Helper to check if record is a single item
    # @return [Boolean]
    def single_item?
      !collection?
    end

    # Check if record is paginated (Kaminari or WillPaginate support)
    # @return [Boolean]
    def paginated?
      record.respond_to?(:current_page) && 
      record.respond_to?(:total_pages) &&
      record.respond_to?(:total_count)
    end

    # Extract pagination metadata from paginated record
    # @return [Hash, nil] Pagination metadata or nil if not paginated
    def pagination_meta
      return nil unless paginated?
      
      {
        current_page: record.current_page,
        total_pages: record.total_pages,
        total_count: record.total_count,
        per_page: record.try(:limit_value) || record.try(:per_page)
      }.compact
    end

    # Render collection with automatic pagination support
    # @param records [Array, ActiveRecord::Relation] Records to render
    # @param additional_meta [Hash] Additional metadata to include
    def render_collection_with_meta(records = nil, additional_meta = {})
      records ||= record
      response = { data: serialize_collection(records) }
      
      # Auto-detect pagination
      if records.respond_to?(:current_page)
        meta = {
          current_page: records.current_page,
          total_pages: records.total_pages,
          total_count: records.total_count,
          per_page: records.try(:limit_value) || records.try(:per_page)
        }.compact
        response[:meta] = meta.merge(additional_meta)
      elsif additional_meta.any?
        response[:meta] = additional_meta
      end
      
      render_json(response)
    end
  end
end
