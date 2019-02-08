module BlocRecord
  def sel.connect_to(filename, dbms)
    @database_filename = filename
    @dbms = dbms
  end

  def self.database_filename
    @database_filename
  end

   def self.dbms
     @dbms
   end 

end
