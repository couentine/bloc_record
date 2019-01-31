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

  def joins(*args)
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
end