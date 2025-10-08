# ApplicationSerializer - Base class for all serializers
# 
# This follows Rails convention (like ApplicationRecord, ApplicationController).
# All your model serializers should inherit from this class.
#
# @example Creating a model serializer
#   class ProductSerializer < ApplicationSerializer
#     def serializable_hash
#       case context[:view]
#       when :summary
#         summary_hash
#       when :minimal
#         minimal_hash
#       else
#         full_hash
#       end
#     end
#     
#     private
#     
#     def full_hash
#       {
#         id: resource.id,
#         name: resource.name,
#         description: resource.description,
#         price: resource.price,
#         created_at: resource.created_at
#       }
#     end
#     
#     def summary_hash
#       {
#         id: resource.id,
#         name: resource.name,
#         price: resource.price
#       }
#     end
#     
#     def minimal_hash
#       {
#         id: resource.id,
#         name: resource.name
#       }
#     end
#   end
class ApplicationSerializer
  attr_reader :resource, :context

  # Initialize serializer with resource and optional context
  # @param resource [Object] The object to serialize
  # @param context [Hash] Additional context (e.g., current_user, view type)
  def initialize(resource, context = {})
    @resource = resource
    @context = context
  end

  # Override this method in your serializers
  # @return [Hash] Serialized representation of the resource
  def serializable_hash
    raise NotImplementedError, "#{self.class.name} must implement #serializable_hash"
  end

  # Access to current_user from context
  # @return [User, nil]
  def current_user
    @context[:current_user]
  end

  # Access to view type from context
  # @return [Symbol, nil] e.g., :summary, :minimal, :full
  def view
    @context[:view]
  end

  # Helper to serialize associations
  # @param association [Object, Array] Association to serialize
  # @param serializer_class [Class] Serializer class to use
  # @return [Hash, Array<Hash>]
  def serialize_association(association, serializer_class)
    return nil if association.nil?
    
    if association.respond_to?(:map)
      association.map { |item| serializer_class.new(item, context).serializable_hash }
    else
      serializer_class.new(association, context).serializable_hash
    end
  end
end
