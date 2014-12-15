require 'sinatra'
require 'sinatra/reloader'
require 'json'
require 'pry-byebug'

require './lib/chatitude'

class Chatitude::Server < Sinatra::Application

  # use thin instead of webrick
  configure do
    enable :sessions
    set server: 'thin'
  end

  # helpers for connecting to db and prerparing json responses
  helpers do
    def db
      Chatitude.create_db_connection 'chatitude'
    end

    def timestamp
      Time.now.to_i
    end

    def respond sender, message
      {
        :sender    => sender,
        :message   => message,
        :timestamp => timestamp
      }.to_json
    end

    def parse_message input
      msg_pieces = input.split
      data = {sender: @current_user['username']}
      if msg_pieces.first == '/pm'
        data.merge({
          :recipient => msg_pieces[1],
          :message   => msg_pieces[2..-1].join(' ')
        })
      else
        data.merge({
          :recipient => :all,
          :message   => input
        })
      end
    end
  end

  # run this before every endpoint to get the current user
  before do
    content_type 'application/json'
    # this condition assign the current user if someone is logged in
    if params[:apiToken]
      @current_user = Chatitude::UsersRepo.find_by_token db, params[:apiToken]
    end

    # the next few lines are to allow cross domain requests
    headers["Access-Control-Allow-Origin"] = "*"
    headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    headers["Access-Control-Allow-Headers"] = "Origin, X-Requested-With, Content-Type, Accept"
  end

  # Array used to store event streams
  # connections = []

  messages, message_count = [], 0

  ############ MAIN ROUTES ###############

  # get '/' do
  #   erb :index
  # end

  post '/signup' do
    errors = []
    if !params[:password] || params[:password] == ''
      errors << 'blank_password'
    end
    if !params[:username] || params[:username] == ''
      errors << 'blank_username'
    end

    if errors.count == 0
      user_data = {username: params[:username], password: params[:password]}
      user = Chatitude::UsersRepo.save db, user_data
      session[:user_id] = user['id']
      status 200
    else
      status 400
      { errors: errors }.to_json
    end
  end

  post '/signin' do
    user = Chatitude::UsersRepo.find_by_name db, params[:username]

    if user && user['password'] == params[:password]
      token = Chatitude::UsersRepo.sign_in db, user['id']
      { apiToken: token }.to_json
    else
      status 401
    end
  end

  delete '/signout' do
    Chatitude::UsersRepo.sign_out db, params[:apiToken]
    status 200
  end

  ##########################################
  # event stream stuff.

  get '/chats' do
    if params[:since]
      messages.select { |m| params[:since] < m['time'] }
    else
      messages.last 10
    end.to_json
  end

  post '/chats' do
    if @current_user

      msg = params[:message]
      if msg.nil? || msg == ''
        status 400
        return { errors: ["blank_message"] }.to_json
      elsif messages.find {|m| m[:message] == msg }
        status 400
        return { errors: ["message_already_exists"] }.to_json
      end

      message_count += 1
      messages << {
        user: @current_user['username'],
        message: msg,
        time: timestamp,
        id: message_count
      }
      status 200
    else
      status 403
      { errors: "invalid_api_key" }.to_json
    end
  end

end
