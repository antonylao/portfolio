require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

require "redcarpet"
require "yaml"
require "bcrypt"
require "fileutils"
require 'sysrandom/securerandom'

require 'pry'

UPDATE_ORDER_FILE = "update_order.yml".freeze
DATA_FILES_EXT = %w[.txt .md .markdown]
IMAGE_EXT = %w[.jpe .jpg .jpeg .gif .png .bmp .ico .svg .svgz .tif .tiff .ai .drw .pct .psp .xcf .psd .raw .webp].freeze


configure do
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
end

helpers do
end

def image_extension?(path)
  file_extension = File.extname(path)
  IMAGE_EXT.include?(file_extension)
end

# Returns the content of the file. If the file has a 'txt' extension, assign the Content-Type header to "text/plain"
def load_file_content(path)
  content = File.read(path)
  file_extension = File.extname(path)

  if file_extension == ".txt"
    headers["Content-Type"] = "text/plain"
    content
  elsif [".md", ".markdown"].include? file_extension
    erb render_markdown(content) # we use the erb() method to have the stylesheet applied to the markdow
  elsif image_extension?(path)
    filename = File.basename(path)
    erb render_markdown("![image info](/pictures/#{filename})")
    # this is an URL! i.e it tries to access localhost:4567/path_written
    # it works because images are stored in public path (see README.md NB)
  end
end

# Renders markdown files
def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)

  markdown.render(text)
end

# Change the path of the data files depending if we are testing or not
# NB: accessible in cms_test.rb because it is defined on a global scope
def data_path
  # we use the absolute path for the app to be able to be started from another directory
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def history_path(filename)
  File.join(data_path, "history/#{filename}")
end

def pictures_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/public/pictures", __FILE__)
  else
    File.expand_path("../public/pictures", __FILE__)
  end
end

def user_credentials_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end

# List the files inside a folder (subfolders are ignored)
def list_only_files(root_folder_path)
  pattern = File.join(root_folder_path, "*")

  only_file_paths = Dir.glob(pattern).select do |path|
                     File.file?(path)
                    end

  only_file_paths.map do |path|
    File.basename(path)
  end
end

def load_user_credentials
  YAML.load_file(user_credentials_path)
end

def list_usernames
  credentials = load_user_credentials

  credentials.keys
end

# check if the credentials are valid (return boolean)
def valid_credentials?(username, password)
  credentials = load_user_credentials

  credentials.key?(username) && BCrypt::Password.new(credentials[username]) == password
end

def user_signed_in?
  !!session[:signed_in]
  # LS solution (don't use session[:signed_in]): session.key?(:username)
end

def require_signed_in_user
  return if user_signed_in?

  session[:message] = "You must be signed in to do that."
  redirect "/"
end

def valid_filename?(name)
  name = name.to_s.strip

  !name.empty? && !list_only_files(data_path).include?(name) && DATA_FILES_EXT.include?(File.extname(name))
end

def error_message_invalid_filename(name)
  if name.empty?
    "A name is required."
  elsif list_only_files(data_path).include?(name)
    "A file with this name already exists."
  elsif !DATA_FILES_EXT.include?(File.extname(name))
    "This file extension is not supported. " \
    "Please try again with one of the following extensions: " \
    "#{DATA_FILES_EXT.join(', ')}."
  end
end

# Append to filename while keeping the extension at the end
def append_to_filename(filename, append)
  extension = File.extname(filename)
  filename_no_ext = filename.delete_suffix(extension)

  filename_no_ext + append + extension
end

def valid_signup?(username, password1, password2)
  !username.empty? && !list_usernames.include?(username) && password1 == password2 && !password1.empty?
end

def error_message_invalid_signup(username, password1, password2)
  if username.empty?
    "The username field cannot be empty."
  elsif password1.empty? || password2.empty?
    "The password fields cannot be empty."
  elsif list_usernames.include?(username)
    "The username '#{username}' is already taken."
  elsif password1 != password2
    "The passwords entered do not match."
  end
end

def add_credentials_to_users_yml(username, plain_password)
  hashed_pwd = BCrypt::Password.create(plain_password)
  add_line_to_file(user_credentials_path, "#{username}: #{hashed_pwd}")
end

# Checks if there is a history folder for a given file
def history?(filename)
  history_dir_path = history_path(filename)
  Dir.exist?(history_dir_path) && !Dir.empty?(history_dir_path)
end

# Add version no if the filepath is already taken
def add_version_no_to_existing_filepath(path)
  original_filename = File.basename(path)
  directory = File.dirname(path)

  updated_path = path
  version_no = 2
  while File.exist?(updated_path)
    updated_filename = append_to_filename(original_filename, "(#{version_no})")
    updated_path = File.join(directory, updated_filename)
    version_no += 1
  end

  updated_path
end

# add content in a new line. If the file already ends with new line, do not append an extra new line
def add_line_to_file(path, line)
  File.open(path, "a") do |file|
    file.write("\n") unless File.readlines(file)[-1].end_with?("\n")
    file.write(line)
  end
end

# Create history UPDATE_ORDER_FILE document : needs to have the folder file /data/history/<filename>
# file keeps track of the order of update
def create_history_yml(original_filename, filename_zero)
  content = <<~HEREDOC
    ---
    0: #{filename_zero}
  HEREDOC

  yml_file_path = File.join(history_path(original_filename), UPDATE_ORDER_FILE)
  File.write(yml_file_path, content)
end

# Add the updated file to the history UPDATE_ORDER_FILE
def update_history_yml(original_filename, updated_history_filename)
  yml_file_path = File.join(history_path(original_filename), UPDATE_ORDER_FILE)

  # find the next key in the yml database
  yml_hash = YAML.load_file(yml_file_path)
  key_nb = yml_hash.size # hash starts with key "0"

  add_line_to_file(yml_file_path, "#{key_nb}: #{updated_history_filename}")
end

def valid_picture?(picture)
  picture_files = list_only_files(pictures_path)
  filename = picture[:filename] if picture

  !!picture && image_extension?(filename) && !picture_files.include?(filename)
end

def error_message_invalid_picture(picture)
  picture_files = list_only_files(pictures_path)
  filename = picture[:filename] if picture

  if !picture
    "You didn't choose a file."
  elsif !image_extension?(filename)
    <<~HEREDOC
      This format of image is not supported.
      Please try again with one of the following extensions: #{IMAGE_EXT.join(', ')}
    HEREDOC
  elsif picture_files.include?(filename)
    "A picture with this name already exists."
  end
end

def upload_picture_file(picture)
  filename = picture[:filename]
  tempfile = picture[:tempfile]

  FileUtils.mkdir_p(pictures_path) unless Dir.exist?(pictures_path)
  target_path = File.join(pictures_path, filename)

  File.open(target_path, 'wb') { |file| file.write(tempfile.read) }
end

# Create folders if folder data/history/:filename does not exist
def create_history_file_folder(filename)
  history_dir_path = history_path(filename)
  FileUtils.mkdir_p(history_dir_path) unless Dir.exist?(history_dir_path)
end

def add_original_file_to_history(filename, history_original_filename)
  original_filepath = File.join(data_path, filename)
  original_file_content = File.read(original_filepath)

  history_original_filepath = File.join(history_path(filename), history_original_filename)
  File.write(history_original_filepath, original_file_content)
end

def append_current_time_to_filename(filename)
  time = Time.now.utc.to_s.split.join("_")
  append_to_filename(filename, "_#{time}")
end

def add_updated_file_to_history(filename, history_updated_filename, updated_content)
  history_updated_filepath = File.join(history_path(filename), history_updated_filename)

  # edge case when the filename exists (happens when you update twice in less than a second)
  history_updated_filepath = add_version_no_to_existing_filepath(history_updated_filepath)

  File.write(history_updated_filepath, updated_content)
end

before do
end

after do
end

get "/" do
  @files = list_only_files(data_path)
  @pictures = list_only_files(pictures_path)
  erb :index
end

get "/new" do
  require_signed_in_user
  erb :new
end

# Display the sign in page
get "/users/signin" do
  erb :signin
end

# Display the sign up page
get "/users/signup" do
  erb :signup
end

# Display the file content
get "/:filename" do
  filename = params[:filename]
  dir_path = image_extension?(filename) ? pictures_path : data_path
  file_path = File.join(dir_path, filename)

  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "'#{filename}' does not exist."
    redirect "/"
  end
end

# Edit the content of a file
get "/:filename/edit" do
  require_signed_in_user

  @filename = params[:filename]
  file_path = File.join(data_path, @filename)
  @content = File.read(file_path)

  erb :edit
end

# View history of changes in a file
get "/:filename/history" do
  @filename = params[:filename]

  unless history?(@filename)
    session[:message] = "There is no history yet for '#{@filename}'."
    redirect "/"
  end

  history_yaml_path = File.join(data_path, "history/#{@filename}/#{UPDATE_ORDER_FILE}")
  @history_order = YAML.load_file(history_yaml_path)
  @last_yaml_key = @history_order.size - 1

  erb :history
end

# View a version of a file from history
get "/:filename/history/:history_filename" do
  filename = params[:filename]
  history_filename = params[:history_filename]
  history_file_path = File.join(data_path, "history/#{filename}/#{history_filename}")
  load_file_content(history_file_path)
end

# Create a new file
post "/create" do
  require_signed_in_user

  name = params[:filename].to_s.lstrip
  if valid_filename?(name)
    file_path = File.join(data_path, name)
    File.write(file_path, "") # creates a new empty file

    session[:message] = "#{name} was created."
    redirect "/"
  else
    session[:message] = error_message_invalid_filename(name)
    status 422
    erb :new
  end
end

post "/upload_picture" do
  require_signed_in_user

  @files = list_only_files(data_path)
  @pictures = list_only_files(pictures_path)

  picture = params[:picture]
  filename = picture[:filename] if picture

  if valid_picture?(picture)
    upload_picture_file(picture)
    session[:message] = "#{filename} has been successfully uploaded."
    redirect "/"
  else
    session[:message] = error_message_invalid_picture(picture)
    status 422
    erb :index
  end
end

# sign in the user
post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:signed_in] = true
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials."
    status 422
    erb :signin
  end
end

# Sign out the user
post "/users/signout" do
  session[:signed_in] = false
  session.delete(:username)

  session[:message] = "You have been signed out."
  redirect "/"
end

# Sign up the user
post "/users/signup" do
  username = params[:username].strip
  password1 = params[:password1]
  password2 = params[:password2]

  if !valid_signup?(username, password1, password2)
    session[:message] = error_message_invalid_signup(username, password1, password2)
    status 422
    erb :signup
  else
    add_credentials_to_users_yml(username, password1)
    session[:message] = "You have successfully signed up as '#{username}'."
    redirect "/"
  end
end

# Update the file
post "/:filename" do
  require_signed_in_user

  filename = params[:filename]
  file_path = File.join(data_path, filename)

  unless history?(filename)
    history_original_filename = append_to_filename(filename, "_origin")
    create_history_file_folder(filename)
    add_original_file_to_history(filename, history_original_filename)
    create_history_yml(filename, history_original_filename)
  end

  history_updated_filename = append_current_time_to_filename(filename)
  add_updated_file_to_history(filename,
                              history_updated_filename,
                              params[:content])
  update_history_yml(filename, history_updated_filename)

  # update content of the file
  File.write(file_path, params[:content])
  session[:message] = "#{filename} has been updated."
  redirect "/"
end

# Delete a picture
post "/picture/:filename/delete" do
  require_signed_in_user

  filename = params[:filename]
  file_path = File.join(pictures_path, filename)

  File.delete(file_path)
  session[:message] = "#{filename} has been deleted."

  redirect "/"
end

# Delete a file (and its history)
post "/:filename/delete" do
  require_signed_in_user

  filename = params[:filename]
  file_path = File.join(data_path, filename)

  File.delete(file_path)

  history_dir = File.join(data_path, "history/#{filename}")
  FileUtils.remove_dir(history_dir) if Dir.exist?(history_dir)
  session[:message] = "#{filename} has been deleted."

  redirect "/"
end

# Duplicate a file
post "/:filename/duplicate" do
  require_signed_in_user

  filename = params[:filename]
  file_path = File.join(data_path, filename)
  content = File.read(file_path)

  dup_filepath = add_version_no_to_existing_filepath(file_path)

  File.write(dup_filepath, content)

  session[:message] = "#{filename} has been duplicated."
  redirect "/"
end
