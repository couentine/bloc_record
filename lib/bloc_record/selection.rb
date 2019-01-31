require 'sqlite3'

module Selection
  def find(*ids)
    unless ids.is_a?(integer) || ids.is_a?(array)
      flashError
    end

    if ids.length == 1
      find_one(ids.first)
    else
      rows = connection.execute <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      WHERE id IN (#{ids.join(",")})
      SQL

      row_to_array(rows)
    end
  end

  def find_one(id)
    unless id.is_a?(Integer) || id < 0
      flashError
    end

    row = connection.get_first_row <<-SQL
    SELECT #{columns.join ","} FROM #{table}
    WHERE id = #{id}
  SQL

    init_object_from_row(row)
  end
  def find_by(attribute, value)
    unless attribute.is_a? String
      flashError
    end

     row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      WHERE #{attribute} = #{BlocRecord::Utility.sql_strings(value)};
    SQL

     init_object_from_row(row)
  end

   #missing_method defaults to find_by
  def self.method_missing(method_sym)
    if method_sym.to_s =~ /^find_by(.*)$/
      find_by($1.to_sym, arguments.first)
    else
      super
    end
  end

   def self.respond_to?(method_sym, include_private = false)
    if method_sym.to_s =~ /^find_by(.*)$/
      true
    else
      super
    end
  end

   def find_each(options = {}, &block)
    batch_size = options.delete(:batch_size) || 1000

     rows = connection.execute <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      LIMIT #{batch_size}
    SQL

     rows_to_array(rows).each { |row| yield(row) }
  end

   def find_in_batches(options = {}, &block)
    batch_size = options.delete(:batch_size) || 1000

     rows = connection.execute <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      LIMIT #{batch_size}
    SQL

     yield(rows_to_array(rows), :batch_size)
  end

   def take(num=1)
    unless num > 0
      flashError
    end

     if num > 1
      rows = connection.execute <<-SQL
        SELECT #{columns.join ","} FROM #{table}
        ORDER BY random()
        LIMIT #{num};
      SQL

       rows_to_array(rows)
    else
      take_one
    end
  end

   def take_one
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      ORDER BY random()
      LIMIT 1;
    SQL

     init_object_from_row(row)
  end

   def first
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      ORDER BY id
      ASC LIMIT 1;
    SQL

     init_object_from_row(row)
  end

   def last
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      ORDER BY id
      DESC LIMIT 1;
    SQL

     init_object_from_row(row)
  end

   def all
    rows = connection.execute <<-SQL
      SELECT #{columns.join ","} FROM #{table};
    SQL

     rows_to_array(rows)
  end

  def where(*args)
    return self if args == []
    # 1) Handle array conditions
    # e.g. Entry.where("phone_number = ?", params[:phone_number])
    if args.count > 1
      expression = args.shift # removes the first element and returns it
      params = args
    else
      case args.first
        # 2)Handle string conditions
        #e.g Entry.where(name: 'Blochead', age: 30
      when Hash
        expression_hash = BlocRecord::Utility.convert_keus(args.first)
        expression = expression_hash.map{|key, value| "#{key}=#{BlocRecord::Utility.sql_strings(value)}".join("and")}
      end
    end

    sql = <<-SQL
      SELECT #{columns.join(',')} FROM #{table}
      WHERE #{expression};
    SQL

    #params are passed in to connection.execute(), which handles "?" replacement

    rows = connection.execute(sql, params)
    rows_to_array(rows)
  end


  def inner_where(query, str)
    sql = <<-SQL
      SELECT * FROM #{table}
      #{query}
      WHERE #{str};
    SQL
    rows = connection.execute(sql)
  end


   def not(hash)
    str_condition = hash.map {|k,v| "#{k} != '#{v}'"}.join(" AND ")
    where(str_condition)
  end

  def order(*args)
    orders = {}
    for arg in args
      case arg
      when String
        orders.merge!(string_order(arg)) # merge: a way to combine hashes.
      when Symbol
        orders[arg] = nil
      when Hash
        orders.merge!(arg)
      end
    end

  def join(*args)
    # 3) .join Multiple Association with Symbols
    #if more than one element is passed in, our query JOINS on multiple associations.
    if args.count > 1
      joins = args.map {|arg| "INNER JOIN #{arg} ON {arg}.#{table}_id"}.join(" ")
      rows = connection.execute <<-SQL
        SELECT * FROM #{table}
        #joins
      SQL
    else
      case args.first
      when string
        #1) .join with String SQL 
        # BlocRecord users pass in a handwritten JOIN statement like:
        #e.g. Employee.join(:Departement) results in the query
        # SELECT * FROM employee JOIN deparment ON department.employee_id = employee.id;
        # But this way should follow standard naming conventions.

        rows = connection.execute <<-SQL
          SELECT * FROM #{table}
          INNER JOIN #{args.first} ON  #{args.first}.#{table}_id = #{table}.id
        SQL
      end
    end
    rows_to_array
  end

  def joins(hash)
    join_1 = hash.keys[0]
    join_2 = hash.values[0]

    joins = "INNER JOIN #{join_1} ON #{join_1}.#{table}_id = #{table}.id " +
            "INNER JOIN #{join_2} ON #{join_2}.#{join_1}_id = #{join_1}.id"

    rows = connection.execute <<-SQL
      SELECT * FROM #{table}
      #{joins}
    SQL
    
    arr = rows_to_array(rows)
    arr.unshift(joins)  # To save the JOIN query
    arr
  end

   private
  def init_object_from_row(row)
    if row
      data = Hash[columns.zip(row)]
      new(data)
    end
  end

   def rows_to_array(rows)
    rows.map { |row| new(Hash[columns.zip(row)]) }
  end

   def flashError
    puts "Error: Invalid Input"
    return false
  end

    def string_order(str)
    orders = {}
    conditions = str.split(',')
    if conditions.count > 1  # multiple conditions
      for condition in conditions
        orders.merge!(divide_string(condition))
      end
    else # single condition
      condition = conditions[0]
      orders.merge!(divide_string(condition))
    end
    orders
  end

  # This method takes a single condition in string and returns a hash of a single condition.
  def divide_string(s)
    orders = {}
    str = s.downcase  # To change "ASC" to "asc", "DESC" to "desc"
    if str.include?(" asc") || str.include?(" desc")  # Note: a space before asc/desc
      pair = str.split(' ')  # pair = ["name", "asc"]
      orders[pair[0]] = pair[-1]
    else
      orders[str] = nil
    end
    orders
  end

  # This method changes a hash in a string format.
  def hash_to_str(hash)
    hash.map {|key, val| "#{key} #{val}"}.join(", ")
  end
end