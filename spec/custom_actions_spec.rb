require 'spec_helper'

RSpec.describe JsonapiResponses::Respondable do
  let(:dummy_controller_class) do
    Class.new do
      include JsonapiResponses::Respondable
      
      attr_reader :action_name, :params, :controller_name
      
      def initialize(action_name, controller_name = 'courses')
        @action_name = action_name
        @controller_name = controller_name
        @params = {}
      end
      
      def render(options)
        @rendered_options = options
        options
      end
      
      def rendered_options
        @rendered_options
      end
      
      # Mock serialization methods
      def serialize_collection(collection, serializer_class, context)
        collection.map { |item| { id: item[:id], type: 'test' } }
      end
      
      def serialize_item(item, serializer_class, context)
        { id: item[:id], type: 'test' }
      end
      
      def serialization_user
        {}
      end
    end
  end
  
  let(:dummy_serializer) do
    Class.new do
      def initialize(item, context = {})
        @item = item
        @context = context
      end
      
      def serializable_hash
        { id: @item[:id], type: 'test' }
      end
    end
  end
  
  before do
    stub_const('CourseSerializer', dummy_serializer)
  end

  describe 'explicit action support only' do
    it 'does not automatically map actions' do
      controller = dummy_controller_class.new('public_index')
      records = [{ id: 1 }, { id: 2 }]
      
      result = controller.send(:render_with, records)
      
      expect(result[:json][:error]).to eq("Action not supported")
      expect(result[:json][:details][:action]).to eq("public_index")
      expect(result[:json][:details][:required_method]).to eq("respond_for_public_index")
      expect(result[:status]).to eq(:bad_request)
    end
    
    it 'requires explicit method definition or mapping' do
      controller = dummy_controller_class.new('custom_action')
      record = { id: 1 }
      
      result = controller.send(:render_with, record)
      
      expect(result[:json][:message]).to include("custom_action' is not supported")
      expect(result[:json][:suggestions]).to include("Define a 'respond_for_custom_action' method")
      expect(result[:json][:suggestions]).to include("Use 'map_response_action :custom_action")
    end
  end

  describe 'manual action mapping' do
    let(:controller_class_with_mapping) do
      Class.new(dummy_controller_class) do
        map_response_action :featured, to: :index
        map_response_action :trending, to: :custom_listing
        
        map_response_actions(
          dashboard: :show,
          stats: :custom_stats
        )
      end
    end
    
    it 'uses manual mapping for single actions' do
      controller = controller_class_with_mapping.new('featured')
      records = [{ id: 1 }]
      
      expect(controller).to receive(:respond_to?).with('respond_for_featured', true).and_return(false)
      expect(controller).to receive(:respond_to?).with('respond_for_index', true).and_return(true)
      expect(controller).to receive(:respond_for_index).with(records, CourseSerializer, {})
      
      controller.send(:render_with, records)
    end
    
    it 'uses manual mapping for batch-configured actions' do
      controller = controller_class_with_mapping.new('dashboard')
      record = { id: 1 }
      
      expect(controller).to receive(:respond_to?).with('respond_for_dashboard', true).and_return(false)
      expect(controller).to receive(:respond_to?).with('respond_for_show', true).and_return(true)
      expect(controller).to receive(:respond_for_show).with(record, CourseSerializer, {})
      
      controller.send(:render_with, record)
    end
  end

  describe 'custom response methods' do
    let(:controller_with_custom_methods) do
      controller_class = Class.new(dummy_controller_class) do
        def respond_for_custom_action(record, serializer_class, context)
          render json: { custom: true, data: serialize_item(record, serializer_class, context) }
        end
      end
      
      controller_class.new('custom_action')
    end
    
    it 'uses custom response method when available' do
      record = { id: 1 }
      result = controller_with_custom_methods.send(:render_with, record)
      
      expect(result[:json]).to include(custom: true)
      expect(result[:json][:data]).to include(id: 1, type: 'test')
    end
  end

  describe 'detailed error handling' do
    let(:controller) { dummy_controller_class.new('unsupported_action') }
    
    it 'renders detailed error for unsupported actions' do
      records = [{ id: 1 }]
      result = controller.send(:render_with, records)
      
      expect(result[:json][:error]).to eq("Action not supported")
      expect(result[:json][:message]).to include("unsupported_action' is not supported")
      expect(result[:json][:details][:action]).to eq("unsupported_action")
      expect(result[:json][:details][:controller]).to eq("courses")
      expect(result[:json][:details][:required_method]).to eq("respond_for_unsupported_action")
      expect(result[:json][:suggestions]).to be_an(Array)
      expect(result[:json][:suggestions].size).to eq(2)
      expect(result[:status]).to eq(:bad_request)
    end
  end

  describe 'method resolution order' do
    let(:controller_class_with_all_options) do
      Class.new(dummy_controller_class) do
        map_response_action :test_action, to: :index
        
        def respond_for_test_action(record, serializer_class, context)
          render json: { custom_method: true }
        end
      end
    end
    
    it 'prioritizes custom methods over mapping' do
      controller = controller_class_with_all_options.new('test_action')
      record = { id: 1 }
      
      result = controller.send(:render_with, record)
      
      expect(result[:json]).to include(custom_method: true)
    end
  end
end