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

## Automatic Pagination Support

**New in v1.1.0:** JsonapiResponses now automatically detects and handles paginated collections using Kaminari, making pagination effortless.

### Basic Usage

When you paginate your records with Kaminari, pagination metadata is automatically included in the response:

```ruby
class Api::V1::AcademiesController < ApplicationController
  include JsonapiResponses::Respondable

  def index
    academies = Academy.page(params[:page]).per(15)
    
    # That's it! Pagination is automatic
    render_with(academies)
  end
end
```

**Response:**

```json
{
  "data": [
    { "id": 1, "name": "Academy 1", ... },
    { "id": 2, "name": "Academy 2", ... }
  ],
  "meta": {
    "current_page": 1,
    "total_pages": 5,
    "total_count": 73,
    "per_page": 15
  }
}
```

### How It Works

JsonapiResponses automatically detects if your collection responds to Kaminari's pagination methods:
- `current_page`
- `total_pages`
- `total_count`

If these methods exist, pagination metadata is automatically included in the response.

### With Custom Views

Pagination works seamlessly with different view formats:

```ruby
def index
  academies = Academy
    .includes(:owner, :courses)
    .page(params[:page])
    .per(params[:per_page] || 15)
  
  # Supports view parameter and automatic pagination
  render_with(academies)
end
```

**Request:**
```
GET /api/v1/academies?page=2&per_page=20&view=summary
```

**Response:**
```json
{
  "data": [
    { "id": 21, "name": "Academy 21", ... }
  ],
  "meta": {
    "current_page": 2,
    "total_pages": 4,
    "total_count": 73,
    "per_page": 20
  }
}
```

### Requirements

- **Kaminari gem** must be installed and configured
- Your collection must be paginated with `.page()` method

### Custom Pagination Metadata

You can add additional metadata alongside automatic pagination:

```ruby
def index
  academies = Academy.page(params[:page]).per(15)
  
  render_with(
    academies,
    context: { view: view },
    meta: { 
      fetched_at: Time.current,
      filters_applied: params[:search].present?
    }
  )
end
```

**Response:**
```json
{
  "data": [...],
  "meta": {
    "current_page": 1,
    "total_pages": 5,
    "total_count": 73,
    "per_page": 15,
    "fetched_at": "2024-01-15T10:30:00Z",
    "filters_applied": true
  }
}
```

### Using Pagination Helpers

For custom responders, use the built-in pagination helpers:

```ruby
class AcademyResponder < JsonapiResponses::Responder
  def respond_for_index
    if paginated?(record)
      render json: {
        data: serialize_collection(record, serializer_class, context),
        meta: pagination_meta(record, context)
      }
    else
      render json: {
        data: serialize_collection(record, serializer_class, context)
      }
    end
  end
end
```

Available helpers:
- `paginated?(record)` - Check if record supports pagination
- `pagination_meta(record, context)` - Extract pagination metadata hash
- `render_collection_with_meta(record, serializer_class, context)` - Render with automatic pagination

## Security & Authorization

The `view` parameter is a client-side suggestion and should never be trusted blindly. In a production environment, you must validate whether the `current_user` has permission to see the requested level of detail.

### Secure by Default Pattern

Use your authorization logic (like Pundit) inside the serializer to enforce security:

```ruby
class DigitalProductSerializer < ApplicationSerializer
  def serializable_hash
    # Validate the view against permissions
    authorized_view = authorize_view(context[:view] || :summary)

    case authorized_view
    when :full then full_hash
    when :summary then summary_hash
    else minimal_hash
    end
  end

  private

  def authorize_view(requested_view)
    return requested_view unless requested_view == :full
    
    # Check permission for the 'full' view
    if Pundit.policy!(context[:current_user], resource).show_full?
      :full
    else
      :summary # Fallback to a safe view
    end
  end
end
```

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

For complex actions or non-standard logic (like `bulk_upload`, `export_csv`, or `dashboard_stats`), Responders provide a clean way to encapsulate response logic outside of your controllers.

### Handling Non-Standard Actions

If you have an action that doesn't fit the standard CRUD pattern, you can use the `action:` parameter to route the response to a specific method in your responder.

**1. Define the action in your Responder:**

```ruby
# app/responders/product_responder.rb
class ProductResponder < ApplicationResponder
  # Custom action for bulk uploads
  def bulk_upload
    render_json({
      data: serialize_collection(record),
      meta: {
        processed_at: Time.current,
        total_records: record.count,
        status: 'completed'
      }
    })
  end
end
```

**2. Call it from your Controller:**

```ruby
class Api::V1::ProductsController < ApplicationController
  def bulk_upload
    @products = Product.where(id: params[:ids])
    # The 'action' parameter tells the responder which method to execute
    render_with(@products, responder: ProductResponder, action: :bulk_upload)
  end
end
```

### Why Use Responders for "Rare" Actions?

- **Clean Controllers**: Your controller only handles business logic and fetching data.
- **Specific Metadata**: Non-standard actions often require unique `meta` tags that would clutter a controller.
- **Organization**: Even if you have "weird" actions, they remain organized within the Responder assigned to that controller.

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

    # Serialize using a named method on the serializer (falls back to serializable_hash)
    serialize_for(:my_action)      # Calls serializer.my_action if defined

    # Check record type
    collection?    # true if record is a collection
    single_item?   # true if record is a single item

    # Render JSON
    render_json({ data: [], meta: {} })
  end
end
```

## Action-Scoped Serialization with `serialize_for`

For actions with a custom response envelope (like an email confirmation that returns `{ message:, user: }` instead of the standard `{ data: }`), you can define a named method on the serializer to describe the exact shape of the object for that action.

This mirrors the Pundit convention: just as `PostPolicy#publish?` handles the `publish` action, `UserSerializer#confirm` handles the `confirm` action.

**Rule:** the serializer owns the *shape* of the object; the responder owns the *envelope*.

### How it works

`serialize_for(:action)` instantiates the serializer and calls `.action` on it if defined, otherwise falls back to `serializable_hash`.

### Example

**1. Define the action shape in the serializer** (alongside your existing views):

```ruby
# app/serializers/user_serializer.rb
class UserSerializer < ApplicationSerializer
  def serializable_hash
    case view
    when :minimal then minimal_hash
    when :profile then profile_hash
    else summary_hash
    end
  end

  # Custom shape for the confirm action — reuses an existing private method
  def confirm = auth_hash

  private

  def summary_hash = { id: resource.id, email: resource.email }
  def auth_hash    = { id: resource.id, email: resource.email, confirmed: resource.confirmed? }
end
```

**2. Use `serialize_for` in the responder** — no shape logic leaks in:

```ruby
# app/responders/confirmation_responder.rb
class ConfirmationResponder < ApplicationResponder
  def confirm
    render_json({
      message: context[:message],
      user: serialize_for(:confirm)   # → UserSerializer#confirm
    })
  end
end
```

**3. Controller stays minimal:**

```ruby
class Api::V1::ConfirmationsController < ApplicationController
  def confirm
    # ... validation logic ...
    render_with(
      user,
      responder: ConfirmationResponder,
      action: :confirm,
      serializer: UserSerializer,
      context: { message: I18n.t("auth.confirmation.success") }
    )
  end
end
```

### Fallback behaviour

If the serializer does not define the named method, `serialize_for` silently falls back to `serializable_hash`, so existing serializers require no changes.

```ruby
serialize_for(:confirm)  # → UserSerializer#confirm   (if defined)
serialize_for(:confirm)  # → UserSerializer#serializable_hash  (fallback)
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
