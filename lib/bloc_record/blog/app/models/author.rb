class Author
  include Mongoid::Document
  field :name
  field :_id, type: String, default: ->{ name }
  embeds_many :articles
  
end