require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

load_lists = lambda do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

get "/", &load_lists
get "/lists", &load_lists

get "/lists/new" do
  erb :new_list
end

get "/lists/:index" do
  @list = session[:lists][params[:index].to_i]
  erb :list_view
end

post "/lists" do
  list_name = params[:list_name].strip

  if error = error_for_list_name?(list_name)
    session[:error] = error
    erb :new_list
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'Successfuly added the new list'
    redirect "/lists"
  end
end

helpers do
  def error_for_list_name?(list_name)
    if !(1..100).cover? list_name.size
      "List name must be between 1 and 100 characters"
    elsif session[:lists].any? { |list| list[:name] == list_name }
      "List name must be unique"
    end
  end
end
