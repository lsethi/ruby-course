require 'pg'
require_relative 'chatitude/repos/users_repo.rb'

module Chatitude
  def self.create_db_connection dbname
    PG.connect(host: 'localhost', dbname: dbname)
  end

  def self.clear db
    db.exec <<-SQL
      DELETE FROM users;
      DELETE FROM sessions;
    SQL
  end

  def self.create_tables db
    db.exec <<-SQL
      CREATE TABLE IF NOT EXISTS users(
        id SERIAL PRIMARY KEY,
        username VARCHAR,
        password VARCHAR
      );
      CREATE TABLE IF NOT EXISTS sessions(
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users (id),
        token TEXT UNIQUE
      );
    SQL
  end

  def self.drop_tables db
    db.exec <<-SQL
      DROP TABLE IF EXISTS users;
      DROP TABLE IF EXISTS sessions;
    SQL
  end

  def self.seed_dummy_users db
    db.exec <<-SQL
      INSERT INTO users (username, password)
      VALUES ('nick','nick'), ('kate','kate');
    SQL
  end
end
