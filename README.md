# JsonapiResponses

JsonapiResponses is a Ruby gem that simplifies API response handling by allowing multiple response formats from a single endpoint. Instead of creating separate endpoints for different data requirements, this gem enables frontend applications to request varying levels of detail using the same endpoint.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jsonapi_responses'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install jsonapi_responses
```

## Usage

### Setup

1. Include the respondable module in your `ApplicationController`:

```ruby
class ApplicationController < ActionController::API
  include JsonapiResponses::Respondable
end
```

### Creating Serializers

1. Create an application serializer (follows Rails convention):

```ruby
class ApplicationSerializer
  attr_reader :resource, :context

  def initialize(resource, context = {})
    @resource = resource
    @context = context
  end

  def current_user
    @context[:current_user]
  end
end
```

2. Create your model serializers with different view formats:

```ruby
class DigitalProductSerializer < ApplicationSerializer
  def serializable_hash
    case context[:view]
    when :summary
      summary_hash
    when :minimal
      minimal_hash
    else
      full_hash
    end
  end

  private

  def full_hash
    {
      id: resource.id,
      name: resource.name,
      description: resource.description,
      # ... more attributes
    }
  end

  def summary_hash
    {
      id: resource.id,
      name: resource.name,
      price: resource.price,
      # ... fewer attributes
    }
  end

  def minimal_hash
    {
      id: resource.id,
      name: resource.name,
      # ... minimal attributes
    }
  end
end
```

### Controller Implementation

Use `render_with` in your controllers to handle responses. The view parameter is automatically handled from the request params:

```ruby
class Api::V1::ProductsController < ApplicationController
  def index
    products = Product.includes(:categories, :attachments)
    render_with(products)
  end

  def create
    @product = Product.new(product_params)
    render_with(@product)
  end

  def show
    render_with(@product)
  end

  def update
    @product.update(product_params)
    render_with(@product)
  end

  def destroy
    render_with(@product)
  end

  # Optional: Override the view if needed
  def custom_action
    render_with(@product, context: { view: :custom_view })
  end
end
```

### Making Requests

You can request different view formats by adding the `view` parameter:

```
GET /api/v1/digital_products            # Returns full response
GET /api/v1/digital_products?view=summary  # Returns summary response
GET /api/v1/digital_products?view=minimal  # Returns minimal response
```

### Performance Benefits

By allowing the frontend to request only the needed data, you can:

- Reduce response payload size
- Improve API performance
- Avoid creating multiple endpoints for different data requirements
- Optimize database queries based on the requested view

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Custom Actions Support

Beyond the standard CRUD actions (index, show, create, update, destroy), you can now support custom actions like `public_index`, `export_csv`, `dashboard_stats`, etc.

### Basic Usage

**Option 1: Map to existing actions**

```ruby
class Api::V1::CoursesController < ApplicationController
  include JsonapiResponses::Respondable

  # Map custom actions to existing response methods
  map_response_action :public_index, to: :index
  map_response_action :public_show, to: :show

  def public_index
    # Your logic here
    render_with(@courses)  # Will use respond_for_index
  end
end
```

**Option 2: Define custom response methods**

```ruby
class Api::V1::CoursesController < ApplicationController
  include JsonapiResponses::Respondable

  def dashboard_stats
    # Your logic here
    render_with(@stats)
  end

  private

  def respond_for_dashboard_stats(record, serializer_class, context)
    render json: {
      data: record,
      meta: { type: 'dashboard', generated_at: Time.current }
    }
  end
end
```

**Option 3: Metaprogramming (Recommended for complex scenarios)**

```ruby
class Api::V1::CoursesController < ApplicationController
  include JsonapiResponses::Respondable

  # Generate methods automatically
  generate_rest_responses(
    namespace: 'public',
    actions: [:index, :show],
    context: { access_level: 'public' }
  )

  # Define similar responses in batch
  define_responses_for [:export_csv, :export_pdf] do |record, serializer_class, context|
    format = action_name.to_s.split('_').last
    render json: {
      data: serialize_collection(record, serializer_class, context),
      meta: { export_format: format, total: record.count }
    }
  end
end
```

## Custom Responders - Pundit-Style Pattern (Recommended)

For complex custom actions with specialized response logic, use **one Responder class per controller** (similar to Pundit's policy pattern). This keeps your codebase organized and maintainable.

### Why Use Responders?

- **Separation of Concerns**: Keep response logic out of controllers
- **One Class Per Controller**: Similar to Pundit policies - easy to find and maintain
- **Testability**: Test response logic independently
- **Scalability**: Add new actions without creating new files

### The Pundit-Style Approach

Instead of creating one responder file per action, create **one responder per controller**:

```
app/responders/
├── base_responder.rb        # Common helpers for all responders
├── academy_responder.rb     # ALL academy actions
├── course_responder.rb      # ALL course actions
└── user_responder.rb        # ALL user actions
```

### 1. Create an Application Responder with Common Helpers

```ruby
# app/responders/application_responder.rb
class ApplicationResponder < JsonapiResponses::Responder
  protected

  def render_collection_with_meta(type: nil, additional_meta: {})
    render_json({
      data: serialize_collection(record),
      meta: base_meta.merge({ type: type }.compact).merge(additional_meta)
    })
  end

  def base_meta
    {
      timestamp: Time.current.iso8601,
      count: record_count
    }.compact
  end

  def record_count
    return nil unless collection?
    record.respond_to?(:count) ? record.count : record.size
  end

  def filters_applied
    filter_keys = [:category_id, :level, :status]
    filters = {}
    filter_keys.each { |key| filters[key] = params[key] if params[key].present? }
    filters.empty? ? nil : filters
  end
end
```

### 2. Create One Responder Per Controller with Multiple Actions

```ruby
# app/responders/academy_responder.rb
class AcademyResponder < ApplicationResponder

  # GET /api/v1/academies/featured
  def featured
    if params[:category_id].present?
      render_filtered_featured
    else
      render_all_featured
    end
  end

  # GET /api/v1/academies/popular
  def popular
    render_collection_with_meta(
      type: 'popular',
      additional_meta: {
        period: params[:period] || 'all_time',
        algorithm: 'view_count'
      }
    )
  end

  # GET /api/v1/academies/recommended
  def recommended
    render_collection_with_meta(
      type: 'recommended',
      additional_meta: {
        user_id: current_user&.id,
        based_on: 'user_preferences'
      }
    )
  end

  private

  def render_filtered_featured
    render_json({
      data: serialize_collection(record),
      meta: {
        type: 'featured',
        filtered_by: params[:category_id]
      }
    })
  end

  def render_all_featured
    render_collection_with_meta(type: 'featured')
  end
end
```

### 3. Use it in your controller with the `action:` parameter

```ruby
class Api::V1::AcademiesController < ApplicationController
  include JsonapiResponses::Respondable

  def featured
    @academies = load_featured_academies
    render_with(@academies, responder: AcademyResponder, action: :featured)
  end

  def popular
    @academies = Academy.popular.limit(20)
    render_with(@academies, responder: AcademyResponder, action: :popular)
  end

  def recommended
    @academies = Academy.recommended_for(current_user)
    render_with(@academies, responder: AcademyResponder, action: :recommended)
  end
end
```

### Benefits of This Pattern

**Like Pundit Policies:**

- ✅ One file per controller (not per action)
- ✅ All related logic in one place
- ✅ Easy to find and maintain
- ✅ Shared helpers in base class

**Example Structure:**

```
AcademiesController → AcademyResponder (featured, popular, recommended)
CoursesController   → CourseResponder (featured, search, progress)
UsersController     → UserResponder (dashboard, activity, stats)
```

### Responder API

The `Responder` base class provides useful helpers:

```ruby
class MyCustomResponder < JsonapiResponses::Responder
  def render
    # Access to controller instance
    controller.current_user

    # Access to params
    params[:filter]

    # Serialize data
    serialize_collection(record)  # For collections
    serialize_item(record)         # For single items

    # Check record type
    collection?    # true if record is a collection
    single_item?   # true if record is a single item

    # Render JSON
    render_json({ data: [], meta: {} })
  end
end
```

### Complex Example: Categorized Response

```ruby
# app/responders/categorized_responder.rb
class CategorizedResponder < JsonapiResponses::Responder
  def render
    # Handle pre-structured data or group on the fly
    if structured_data?
      render_json(record)
    else
      render_json(group_by_category)
    end
  end

  private

  def structured_data?
    record.is_a?(Array) &&
    record.first.is_a?(Hash) &&
    record.first.key?(:category)
  end

  def group_by_category
    categories = {}

    serialize_collection(record).each do |item|
      category_id = item.dig(:category, :id) || 'uncategorized'
      categories[category_id] ||= {
        category: item[:category] || { name: 'Uncategorized' },
        items: []
      }
      categories[category_id][:items] << item
    end

    categories.values.map do |group|
      group.merge(count: group[:items].size)
    end
  end
end
```

### When to Use Each Approach

| Approach                | Best For                                    | Complexity |
| ----------------------- | ------------------------------------------- | ---------- |
| `map_response_action`   | Simple actions similar to existing ones     | Low        |
| `respond_for_*` methods | 1-2 custom actions with simple logic        | Medium     |
| Custom Responders       | 3+ custom actions or complex response logic | High       |
| Metaprogramming         | Batch generation of similar actions         | High       |

### Mixing Approaches

You can combine different approaches in the same controller:

```ruby
class Api::V1::ProductsController < ApplicationController
  include JsonapiResponses::Respondable

  # Map simple actions
  map_response_action :public_index, to: :index

  # Use responder for complex actions
  def featured
    @products = Product.featured
    render_with(@products, responder: FeaturedResponder)
  end

  # Use custom method for one-off logic
  def statistics
    render_with(@stats)
  end

  private

  def respond_for_statistics(record, serializer_class, context)
    render json: { stats: record, generated_at: Time.current }
  end
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/jsonapi_responses. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/jsonapi_responses/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the JsonapiResponses project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/jsonapi_responses/blob/main/CODE_OF_CONDUCT.md).
