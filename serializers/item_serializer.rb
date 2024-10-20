# Define Item serializer
class ItemSerializer
  def initialize(item, context = {})
    @item = item
    @context = context
  end

  def serializable_hash
    case @context[:view]
    when :minimal
      minimal_hash
    when :summary
      summary_hash
    else
      full_hash
    end
  end

  private

  # Full Hash response
  def full_hash
    {
      id: @item.id,
      name: @item.name,
      description: @item.description,
      category: @item.category,
      slogan: @item.slogan,
      score: @item.score
    }
  end

  # Summary Hash response
  def summary_hash
    {
      id: @item.id,
      name: @item.name,
      description: @item.description,
      category: @item.category
    }
  end

  # Minimal Hash response
  def minimal_hash
    {
      id: @item.id,
      name: @item.name
    }
  end
end
