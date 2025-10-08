# ApplicationResponder - Base class for all responders
# 
# This follows Rails convention (like ApplicationRecord, ApplicationController)
# and Pundit pattern (like ApplicationPolicy).
#
# Create one responder per controller with multiple action methods inside.
#
# @example Creating a resource responder
#   class ProductResponder < ApplicationResponder
#     # GET /products/featured
#     def featured
#       render_collection_with_meta(
#         type: 'featured',
#         additional_meta: { category: params[:category_id] }
#       )
#     end
#     
#     # GET /products/popular
#     def popular
#       render_collection_with_meta(
#         type: 'popular',
#         additional_meta: { period: params[:period] || 'month' }
#       )
#     end
#   end
#
# @example Using in controller
#   class ProductsController < ApplicationController
#     def featured
#       @products = Product.featured
#       render_with(@products, responder: ProductResponder, action: :featured)
#     end
#   end
class ApplicationResponder < JsonapiResponses::Responder
  # Common helper methods available to all responders
  
  protected
  
  # Render a standard collection with metadata
  # @param type [String, Symbol] Type of collection (e.g., 'featured', 'popular')
  # @param additional_meta [Hash] Additional metadata to include
  def render_collection_with_meta(type: nil, additional_meta: {})
    render_json({
      data: serialize_collection(record),
      meta: base_meta.merge({ type: type }.compact).merge(additional_meta)
    })
  end
  
  # Render a single item with metadata
  # @param additional_meta [Hash] Additional metadata to include
  def render_item_with_meta(additional_meta: {})
    render_json({
      data: serialize_item(record),
      meta: base_meta.merge(additional_meta)
    })
  end
  
  # Render grouped/categorized data
  # @param groups [Array, Hash] Pre-structured grouped data
  def render_grouped_data(groups)
    render_json(groups)
  end
  
  # Base metadata common to all responses
  # @return [Hash] Base metadata including timestamp and count
  def base_meta
    {
      timestamp: Time.current.iso8601,
      count: record_count
    }.compact
  end
  
  # Get the count of records
  # @return [Integer, nil] Count if collection, nil otherwise
  def record_count
    return nil unless collection?
    record.respond_to?(:count) ? record.count : record.size
  end
  
  # Check if a parameter is present
  # @param key [Symbol, String] Parameter key
  # @return [Boolean]
  def param_present?(key)
    params[key].present?
  end
  
  # Get filters applied from params
  # @param filter_keys [Array<Symbol>] Keys to check for filters
  # @return [Hash, nil] Hash of applied filters or nil if none
  def filters_applied(filter_keys = [:category_id, :level, :status, :sort_by, :limit])
    filters = {}
    
    filter_keys.each do |key|
      filters[key] = params[key] if params[key].present?
    end
    
    filters.empty? ? nil : filters
  end
end
