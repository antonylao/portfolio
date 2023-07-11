require "minitest/autorun"
require "rack/test"

require 'fileutils'
require 'pry'

require_relative "../cms"

ENV["RACK_ENV"] = "test"

USERS_YML_CONTENT = <<~HEREDOC
  ---
  admin: $2a$12$npPKuFBb1DVwECGlMKw3fOwm9k7g17hpiHfM/8U0QYcaktNhcU6T.
  test_user: $2a$12$cWTe9Zz3o3zZpxsShG3cZe3tk/ButQ9mKE/SfWteZJGjNfYPLvNre
HEREDOC

#NB: warning: assert_includes with the body response takes into account comments!

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  # access the session hash
  def session
    last_request.env["rack.session"]
  end

  # set session values to be signed in as admin
  def admin_session
    { "rack.session" => { signed_in: true, username: "admin" } }
  end

  def temp_path
    path = File.expand_path("../temp", __FILE__)
  end
  
  def setup
    FileUtils.mkdir(data_path) #create data_path directory (inside the test folder)
    FileUtils.mkdir(temp_path)
    FileUtils.mkdir_p(pictures_path)
    File.write(user_credentials_path, USERS_YML_CONTENT)
  end
  
  def teardown 
    FileUtils.rm_rf(data_path) #remove data_path directory
    FileUtils.rm_rf(temp_path)
    FileUtils.rm_rf(File.expand_path("../public", __FILE__))
    FileUtils.rm(user_credentials_path)
  end
  
  def create_document(name, content: "", path: data_path)
    File.open(File.join(path, name), "w") do |file|
      file.write(content)
    end
  end

  #create a sample file that writes each line except the ones we don't want, then delete the original
  #NB: can't execute it if failure/error happens => not used, instead use setup() and teardown() methods to reinitialize the file content
  def delete_last_line(file_path)
    original_file = File.open(file_path, 'r')
    file_folder = File::dirname(original_file) 
  
    # if the replacement file already exists, the content will be deleted: use 'a' instead or 'w' if you do not want this
    replacement_file = File.open(File.join(file_folder, "temp_file"), 'w')
  
    number_of_lines = original_file.readlines.size
    original_file.rewind 
  
    original_file.each_line.with_index do |line, idx|
      line_no = idx + 1
  
      replacement_file.write(line) unless line_no == number_of_lines
      # other writing (same solution):
      # File.write(replacement_file, line, mode: 'a') unless line_no == number_of_lines
    end
  
    #replace original file by temp file
    FileUtils.mv(replacement_file, original_file)
  
    original_file.close
    replacement_file.close
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]

    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "New Document"
  end
  
  def test_viewing_text_document
    create_document "history.txt", content: "Ruby 0.95 released"

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 0.95 released"
  end

  def test_document_not_found
    get "/notafile.ext"

    assert_equal 302, last_response.status
    assert_equal "'notafile.ext' does not exist.", session[:message]
  end

  def test_viewing_markdown_document
    create_document "about.md", content: "# Ruby is..."

    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_editing_document
    create_document "changes.txt"

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Edit content of changes.txt:"
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, '<button type="submit"' 
  end

  def test_editing_document_signed_out
    create_document "changes.txt"

    get "/changes.txt/edit"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_updating_document
    create_document "changes.txt"

    post "/changes.txt", {content: "new content"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_updating_document_signed_out
    create_document "changes.txt"

    post "/changes.txt", content: "new content"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_view_new_document_form 
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_new_document_form_signed_out
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document
    post "/create", {filename: "test.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt was created.", session[:message]
    
    get last_response["Location"]
    get "/" # refresh the page for the session message to disappear
    assert_nil session[:message]
    refute_includes  last_response.body, "test.txt was created."
    assert_includes last_response.body, %q(href="/test.txt")
  end

  def test_create_new_document_signed_out
    post "/create", filename: "test.txt"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document_without_filename
    post "/create", {filename: ""}, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_create_document_already_existing
    create_document "test.txt"
    post "/create", {filename: "test.txt"}, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "A file with this name already exists."
  end

  def test_create_document_with_wrong_extension
    post "/create", {filename: "test.wrong_ext"}, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "This file extension is not supported. Please try again with one of the following extensions: .txt, .md, .markdown."
  end

  def test_delete_document
    create_document "test.txt"
    
    post "/test.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt has been deleted.", session[:message]

    get "/"
    refute_includes last_response.body, %q(href="/test.txt")
  end

  def test_delete_document_signed_out
    create_document "test.txt"

    post "/test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"

    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin."
    assert_includes last_response.body, "Sign Out"
  end

  def test_sign_in_2
    post "/users/signin", username: "test_user", password: "test_secret"

    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "test_user", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as test_user."
    assert_includes last_response.body, "Sign Out"    
  end

  def test_invalid_sign_in
    post "/users/signin", username: "not_a_user", password: "wrong_password"
    
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid credentials."
  end

  def test_signout
    # we have to sign in before testing the signout process
    get "/", {}, admin_session
    assert_includes last_response.body, "Signed in as admin."
    
    post "/users/signout"

    assert_equal 302, last_response.status
    assert_equal "You have been signed out.", session[:message]

    get last_response["Location"]
    assert_equal false, session[:signed_in]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end

  def test_duplicate
    create_document "test.txt", content: "some content"

    post "/test.txt/duplicate", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt has been duplicated.", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "test(2).txt"

    get "/test(2).txt"
    assert_equal 200, last_response.status
    assert_equal "some content", last_response.body

    post "/test.txt/duplicate"
    get last_response["Location"]
    assert_includes last_response.body, "test(3).txt"
    
    get "/test(3).txt"
    assert_equal 200, last_response.status
    assert_equal "some content", last_response.body
  end

  def test_duplicate_signed_out
    create_document "test.txt", content: "some content"

    post "/test.txt/duplicate"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_signup_form
    get "/users/signup"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Username"
    assert_includes last_response.body, "Password"
    assert_includes last_response.body, "Confirm password"
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signup
    post "/users/signup", {username: "test_signup", password1: "test", password2: "test"}

    assert_equal 302, last_response.status
    assert_equal "You have successfully signed up as 'test_signup'.", session[:message]

    # verify that users.yml file has been updated
    assert_includes(load_user_credentials, "test_signup")
    assert_equal BCrypt::Password.new(load_user_credentials["test_signup"]), "test" 
  end

  def test_signup_username_already_taken
    post "/users/signup", {username: "admin", password1: "test", password2: "test"}

    assert_equal 422, last_response.status
    assert_includes last_response.body, "The username 'admin' is already taken."
  end

  def test_signup_password_not_matching
    post "/users/signup", {username: "admin2", password1: "one", password2: "two"}

    assert_equal 422, last_response.status
    assert_includes last_response.body, "The passwords entered do not match."
  end

  def test_signup_username_field_spaces_only
    post "/users/signup", {username: "     ", password1: "test", password2: "test"}

    assert_equal 422, last_response.status
    assert_includes last_response.body, "The username field cannot be empty."
  end

  def test_signup_password_fields_empty
    post "/users/signup", {username: "admin2", password1: "", password2: ""}

    assert_equal 422, last_response.status
    assert_includes last_response.body, "The password fields cannot be empty."
  end

  def test_updating_document_adds_to_history
    create_document "changes.txt"

    post "/changes.txt", {content: "new content"}, admin_session
    date = Time.now.utc.to_s.split[0]

    get "/changes.txt/history"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "changes_origin.txt"
    assert_includes last_response.body, "changes_#{date}"
    assert_includes last_response.body, "UTC"
  end

  def test_not_updated_document_has_no_history
    create_document "new.txt"

    get "/new.txt/history"
    assert_equal 302, last_response.status
    assert_equal "There is no history yet for 'new.txt'.", session[:message]
  end

  def test_deleting_document_deletes_associated_history_folder
    create_document "changes.txt"
    history_dir_path = File.join(data_path, "history/changes.txt")
    assert_equal false, Dir.exist?(history_dir_path)

    post "/changes.txt", {content: "new content"}, admin_session
    assert_equal true, Dir.exist?(history_dir_path)

    post "/changes.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been deleted.", session[:message]
    assert_equal false, Dir.exist?(history_dir_path)
  end
  
  def test_upload_picture
    create_document("test.jpg", path: temp_path)

    temp_picture_path = File.join(temp_path, "test.jpg")
    post "/upload_picture", {"picture" => Rack::Test::UploadedFile.new(temp_picture_path)}, admin_session

    assert_includes list_only_files(pictures_path), "test.jpg"

    assert_equal 302, last_response.status
    assert_equal "test.jpg has been successfully uploaded.", session[:message]

    get last_response["Location"]
    get "/" # refresh the page for the session message to disappear
    assert_includes last_response.body, "test.jpg"
  end

  def test_upload_picture_signed_out
    post "/upload_picture"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_upload_picture_no_file
    post "/upload_picture", {}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "You didn't choose a file."
  end

  def test_upload_picture_wrong_file_extension
    filename = "test.txt"
    create_document(filename, path: temp_path)

    temp_picture_path = File.join(temp_path, filename)
    post "/upload_picture", {"picture" => Rack::Test::UploadedFile.new(temp_picture_path)}, admin_session

    assert_equal 422, last_response.status
    message = <<~HEREDOC
      This format of image is not supported.
      Please try again with one of the following extensions: #{IMAGE_EXT.join(', ')}
    HEREDOC
    assert_includes last_response.body, message
  end

  def test_upload_picture_existing_filename
    filename = "test.jpg"
    create_document(filename, path: temp_path)
    temp_picture_path = File.join(temp_path, filename)
    post "/upload_picture", {"picture" => Rack::Test::UploadedFile.new(temp_picture_path)}, admin_session

    assert_includes list_only_files(pictures_path), filename

    post "/upload_picture", {"picture" => Rack::Test::UploadedFile.new(temp_picture_path)}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A picture with this name already exists."

  end

  def test_delete_picture
    filename = "test.jpg"
    create_document(filename, path: temp_path)
    temp_picture_path = File.join(temp_path, filename)
    post "/upload_picture", {"picture" => Rack::Test::UploadedFile.new(temp_picture_path)}, admin_session

    assert_includes list_only_files(pictures_path), filename
    get "/"
    assert_includes last_response.body, %q(href="/test.jpg")

    post "/picture/test.jpg/delete"
    assert_equal 302, last_response.status
    assert_equal "test.jpg has been deleted.", session[:message]

    get "/" #refresh the page
    refute_includes last_response.body, %q(href="/test.jpg")
  end

  def test_delete_picture_signed_out
    filename = "test.jpg"
    create_document(filename, path: pictures_path)

    post "/picture/#{filename}/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
end
