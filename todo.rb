require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "pry"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
  set :show_exceptions, :after_handler
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
  @index = params[:index].to_i
  halt 404 if @index >= session[:lists].size
  @list = session[:lists][@index]
  @todos = session[:lists][@index][:todos]
  @status = session[:lists][@index][:status]
  erb :list_view
end

get "/lists/:index/edit" do
  @index = params[:index].to_i
  @list = session[:lists][@index]

  erb :edit_list
end

post "/lists" do
  list_name = params[:list_name].strip

  if error = error_for_list_name?(list_name)
    session[:error] = error
    erb :new_list
  else
    session[:lists] << { name: list_name, todos: [], status: [] }
    session[:success] = 'Successfuly added the new list'
    redirect "/lists"
  end
end

post "/lists/:index" do
  @index = params[:index].to_i
  @list = session[:lists][@index]
  @todos = session[:lists][@index][:todos]
  list_name = params[:list_name].strip

  if error = error_for_list_name?(list_name)
    session[:error] = error
    erb :edit_list
  else
    @list[:name] = params[:list_name]
    session[:success] = 'Successfuly edited the list name'
    redirect "/lists"
  end
end

post "/lists/:index/destroy" do
  @index = params[:index].to_i
  session[:lists].delete_at(@index)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "Successfuly deleted the list"
    redirect "/lists"
  end
end

post "/lists/:index/todos" do
  @index = params[:index].to_i
  @list = session[:lists][@index]
  @todos = session[:lists][@index][:todos]
  @status = session[:lists][@index][:status]

  todo_name = params[:todo].strip

  if error = error_for_todo_name?(todo_name, @todos)
    session[:error] = error
    erb :list_view
  else
    @todos << todo_name
    @status << ""
    session[:success] = 'Successfuly added the todo.'
    redirect "/lists/#{@index}"
  end
end

post "/lists/:index/todos/:todo_idx/destroy" do
  @index = params[:index].to_i
  @list = session[:lists][@index]
  @todos = session[:lists][@index][:todos]
  @todo_idx = params[:todo_idx].to_i

  session[:lists][@index][:status].delete_at(@todo_idx)
  @todos.delete_at(@todo_idx)


  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "Successfuly deleted todo"
    redirect "/lists/#{@index}"
  end
end

post "/lists/:index/todos/:todo_idx/status" do
  @index = params[:index].to_i
  @todo_idx = params[:todo_idx].to_i
  @status = session[:lists][@index][:status]

  session[:success] = "Todo has been updated"
  @status[@todo_idx] = params[:completed].empty? ? "complete" : ""
  redirect "/lists/#{@index}"
end

post "/lists/:index/todos/complete" do
  @index = params[:index].to_i
  @status = session[:lists][@index][:status]

  @status.map! { |todo_status| "complete" }
  session[:success] = "All todos have been completed"
  redirect "/lists/#{@index}"
end

error 404 do
  session[:error] = "Sorry the page you are looking for does not exist"
  redirect "/lists"
end

helpers do
  def error_for_list_name?(list_name)
    if !(1..100).cover? list_name.size
      "List name must be between 1 and 100 characters"
    elsif session[:lists].any? { |list| list[:name] == list_name }
      "List name must be unique"
    end
  end

  def error_for_todo_name?(todo_name, todos)
    if !(1..100).cover? todo_name.size
      "Todo name must be between 1 and 100 characters"
    elsif todos.any? { |todo| todo == todo_name }
      "Todo name must be unique"
    end
  end

  def todos_complete?(list_index)
    index = list_index.to_i
    total_todos(index) > 0 &&
      num_todos_complete(index) == total_todos(index)
  end

  def num_todos_complete(list_index)
    session[:lists][list_index][:status]
      .select { |status| status == 'complete' }.size
  end

  def total_todos(list_index)
    session[:lists][list_index][:todos].size
  end

  def sort_lists(lists)
    lists.sort_by { |_, index| todos_complete?(index) ? 1 : 0 }
  end

  def sort_todos(todos, list_index)
    status = session[:lists][list_index][:status]
    todos.sort_by { |_, index| status[index] == 'complete'  ? 1 : 0 }
  end
end
