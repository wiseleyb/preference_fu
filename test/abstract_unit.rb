begin
  require File.dirname(__FILE__) + '/../../../../config/environment'
rescue LoadError
  require 'rubygems'
  require_gem 'activerecord'
end

require 'preference_fu'
require "#{File.dirname(__FILE__)}/../init"

def setup_db
  @db = ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")
  ActiveRecord::Schema.define(:version => 1) do
    create_table :people do |t|
      t.string      :name
      t.integer     :preferences
      t.integer     :reminders
    end
    
    create_table :tasks do |t|
      t.string      :name
      t.integer     :reminders
    end
  end
end

def teardown_db
  sleep(1)
  @db.tables.each do |table|
    @db.drop_table(table)
  end
  @db.disconnect!
end