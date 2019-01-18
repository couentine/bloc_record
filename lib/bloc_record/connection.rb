requie 'sqlite3'

module Connection
  def Connection
    @connection ||= SQLite3::Database.new(BlocRecord.database_filename)
  end
end
