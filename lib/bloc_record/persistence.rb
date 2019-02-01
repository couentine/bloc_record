require 'sqlite3'
require 'bloc_record/schema'

module Persistence

  def self.included(base)
    base.extend(ClassMethods)
  end

  def save
    self.save! rescue false
  end

  def save!
    unless self.id
      self.id = self.class.create(BlocRecord::Utility.instance_variables_to_hash(self)).id
      BlocRecord::Utility.reload_obj(self)
      return true
    end

    fields = self.class.attributes.map { |col| "#{col}=#{BlocRecord::Utility.sql_strings(self.instance_variable_get("@#{col}"))}" }.join(",")

    self.class.connection.execute <<-SQL
      UPDATE #{self.class.table}
      SET #{fields}
      WHERE id = #{self.id};
    SQL

    true
  end

  def update_attribute(attribute, value)
    self.class.update(self.id, { attribute => value })
  end

  def update_attributes(updates)
    self.class.update(self.id, updates)
  end

  def method_missing(m, *args, &block)
    if m[0..] == "update_"
      attribute = m[7..m.length-1]
      find_by(attribute, args[0])
    else
      raise NoMethodError
    end
  end

  module ClassMethods
    def create(attrs)
      attrs = BlocRecord::Utility.convert_keys(attrs)
      attrs.delete "id"
      vals = attributes.map { |key| BlocRecord::Utility.sql_strings(attrs[key]) }

      connection.execute <<-SQL
        INSERT INTO #{table} (#{attributes.join ","})
        VALUES (#{vals.join ","});
      SQL

      data = Hash[attributes.zip attrs.values]
      data["id"] = connection.execute("SELECT last_insert_rowid();")[0][0]
      new(data)
    end

    def update_all(updates)
      update(nil, updates)
    end

    def update(ids, updates)
    	if ids.class == Array && updates.class == Array
        update = ids.zip(updates)
        update.each { |id, update| 
          update_each(id, update)
        }
      else
        update_each(ids , updates)
      end
    end

    def method_missing(m, *args, &block) 
      	if m.match?(/update/)
        attribute =  m.to_s[7..-1]
        values = args[0]

         unless columns.index("#{attribute}").nil?
          return self.update(self.id, { attribute => values })
        end

         return "Invalid Argument: #{m} >> There is no such column: '#{attribute}' -- please try again."  
      else
        return "Invalid Method: #{m} >> The method called does not exist -- please try again."  
      end  


     def update_each(ids, updates)
      updates = BlocRecord::Utility.convert_keys(updates)
      updates.delete "id"
      updates_array = updates.map { |key, value| "#{key}=#{BlocRecord::Utility.sql_strings(value)}" }
      if ids.class == Fixnum
        where_clause = "WHERE id = #{ids};"
      elsif ids.class == Array
        if ids.empty?
          where_clause = ";"
        else
          where_clause = "WHERE id IN (#{ids.join(",")});"
      else
        where_clause = ";"
      end

      connection.execute <<-SQL
        UPDATE #{table}
        SET #{updates_array * ","} #{where_clause}
      SQL

      true
    end
  end
end
