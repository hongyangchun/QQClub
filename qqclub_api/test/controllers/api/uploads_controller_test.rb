# frozen_string_literal: true

require "test_helper"

class Api::UploadsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user(:user)
    @admin = create_test_user(:admin)
    @tmp_upload_dir = Rails.root.join('tmp', 'uploads')
    FileUtils.mkdir_p(@tmp_upload_dir) unless Dir.exist?(@tmp_upload_dir)
  end

  def teardown
    # 清理测试创建的文件
    Dir.glob(File.join(@tmp_upload_dir, '*')).each do |file|
      File.delete(file) if File.exist?(file)
    end
  end

  # Authentication Tests
  test "should require authentication for image upload" do
    post '/api/upload/image'
    assert_response :unauthorized
  end

  # Validation Tests
  test "should return error when no file provided" do
    post '/api/upload/image', headers: authenticate_user(@user)
    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_equal '请选择图片文件', json_response['error']
  end

  test "should return error for unsupported file type" do
    # 创建一个临时的非图片文件
    temp_file = Tempfile.new(['test', '.txt'])
    temp_file.write('This is not an image')
    temp_file.rewind

    post '/api/upload/image', params: { file: Rack::Test::UploadedFile.new(temp_file.path, 'text/plain') }, headers: authenticate_user(@user)
    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_equal '只支持 JPG、PNG、GIF 格式的图片', json_response['error']

    temp_file.close
    temp_file.unlink
  end

  test "should return error for oversized file" do
    # 创建一个超过5MB的临时文件
    temp_file = Tempfile.new(['large_test', '.jpg'])
    temp_file.write('x' * (6.megabytes))
    temp_file.rewind

    post '/api/upload/image', params: { file: Rack::Test::UploadedFile.new(temp_file.path, 'image/jpeg') }, headers: authenticate_user(@user)
    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_equal '图片大小不能超过5MB', json_response['error']

    temp_file.close
    temp_file.unlink
  end

  # Success Tests
  test "should successfully upload JPEG image" do
    # 创建一个临时的图片文件
    temp_file = Tempfile.new(['test_image', '.jpg'])
    temp_file.write("test_image_content" * 100) # 小于5MB
    temp_file.rewind

    post '/api/upload/image', params: { file: Rack::Test::UploadedFile.new(temp_file.path, 'image/jpeg') }, headers: authenticate_user(@user)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal '图片上传成功', json_response['message']
    assert json_response['url']
    assert json_response['file_name']
    assert json_response['url'].start_with?('/uploads/')

    # 验证文件确实被保存了
    file_path = Rails.root.join('tmp', 'uploads', json_response['file_name'])
    assert File.exist?(file_path)

    temp_file.close
    temp_file.unlink
  end

  test "should successfully upload PNG image" do
    # 创建一个临时的PNG文件
    temp_file = Tempfile.new(['test_image', '.png'])
    temp_file.write("test_png_content" * 100) # 小于5MB
    temp_file.rewind

    post '/api/upload/image', params: { file: Rack::Test::UploadedFile.new(temp_file.path, 'image/png') }, headers: authenticate_user(@user)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal '图片上传成功', json_response['message']
    assert json_response['url']
    assert json_response['file_name']

    temp_file.close
    temp_file.unlink
  end

  test "should successfully upload GIF image" do
    # 创建一个临时的GIF文件
    temp_file = Tempfile.new(['test_image', '.gif'])
    temp_file.write("test_gif_content" * 100) # 小于5MB
    temp_file.rewind

    post '/api/upload/image', params: { file: Rack::Test::UploadedFile.new(temp_file.path, 'image/gif') }, headers: authenticate_user(@user)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal '图片上传成功', json_response['message']
    assert json_response['url']
    assert json_response['file_name']

    temp_file.close
    temp_file.unlink
  end

  test "should generate unique filename for each upload" do
    # 创建两个临时文件
    temp_file1 = Tempfile.new(['test_image1', '.jpg'])
    temp_file2 = Tempfile.new(['test_image2', '.jpg'])

    temp_file1.write("content1" * 100)
    temp_file1.rewind

    temp_file2.write("content2" * 100)
    temp_file2.rewind

    # 上传第一个文件
    post '/api/upload/image', params: { file: Rack::Test::UploadedFile.new(temp_file1.path, 'image/jpeg') }, headers: authenticate_user(@user)
    assert_response :success

    response1 = JSON.parse(response.body)
    filename1 = response1['file_name']

    # 上传第二个文件
    post '/api/upload/image', params: { file: Rack::Test::UploadedFile.new(temp_file2.path, 'image/jpeg') }, headers: authenticate_user(@user)
    assert_response :success

    response2 = JSON.parse(response.body)
    filename2 = response2['file_name']

    # 文件名应该不同
    assert_not_equal filename1, filename2

    # 两个文件都应该存在
    assert File.exist?(Rails.root.join('tmp', 'uploads', filename1))
    assert File.exist?(Rails.root.join('tmp', 'uploads', filename2))

    temp_file1.close
    temp_file1.unlink
    temp_file2.close
    temp_file2.unlink
  end

  test "should preserve original filename in generated filename" do
    # 创建一个带有特定名称的临时文件
    temp_file = Tempfile.new(['my_test_image', '.jpg'])
    temp_file.write("test_content" * 100)
    temp_file.rewind

    post '/api/upload/image', params: { file: Rack::Test::UploadedFile.new(temp_file.path, 'image/jpeg', original_filename: 'my_test_image.jpg') }, headers: authenticate_user(@user)
    assert_response :success

    json_response = JSON.parse(response.body)
    filename = json_response['file_name']

    # 文件名应该包含原始文件名
    assert filename.include?('my_test_image.jpg')

    temp_file.close
    temp_file.unlink
  end

  test "should work for different user roles" do
    temp_file = Tempfile.new(['test_image', '.jpg'])
    temp_file.write("test_content" * 100)
    temp_file.rewind

    # 普通用户应该能够上传
    post '/api/upload/image', params: { file: Rack::Test::UploadedFile.new(temp_file.path, 'image/jpeg') }, headers: authenticate_user(@user)
    assert_response :success

    # 管理员也应该能够上传
    post '/api/upload/image', params: { file: Rack::Test::UploadedFile.new(temp_file.path, 'image/jpeg') }, headers: authenticate_user(@admin)
    assert_response :success

    temp_file.close
    temp_file.unlink
  end

  # MIME Type Tests
  test "should accept image/jpeg MIME type" do
    temp_file = Tempfile.new(['test', '.jpg'])
    temp_file.write("test_content" * 100)
    temp_file.rewind

    post '/api/upload/image', params: { file: Rack::Test::UploadedFile.new(temp_file.path, 'image/jpeg') }, headers: authenticate_user(@user)
    assert_response :success

    temp_file.close
    temp_file.unlink
  end

  test "should accept image/jpg MIME type" do
    temp_file = Tempfile.new(['test', '.jpg'])
    temp_file.write("test_content" * 100)
    temp_file.rewind

    post '/api/upload/image', params: { file: Rack::Test::UploadedFile.new(temp_file.path, 'image/jpg') }, headers: authenticate_user(@user)
    assert_response :success

    temp_file.close
    temp_file.unlink
  end

  test "should reject invalid MIME type" do
    temp_file = Tempfile.new(['test', '.jpg'])
    temp_file.write("test_content" * 100)
    temp_file.rewind

    post '/api/upload/image', params: { file: Rack::Test::UploadedFile.new(temp_file.path, 'application/pdf') }, headers: authenticate_user(@user)
    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_equal '只支持 JPG、PNG、GIF 格式的图片', json_response['error']

    temp_file.close
    temp_file.unlink
  end

  # Edge Cases Tests
  test "should handle empty file" do
    # 创建一个空的图片文件
    temp_file = Tempfile.new(['empty_image', '.jpg'])
    temp_file.rewind

    post '/api/upload/image', params: { file: Rack::Test::UploadedFile.new(temp_file.path, 'image/jpeg') }, headers: authenticate_user(@user)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal '图片上传成功', json_response['message']

    temp_file.close
    temp_file.unlink
  end

  test "should handle file system errors gracefully" do
    # 模拟文件系统错误 - 临时删除上传目录
    upload_dir = Rails.root.join('tmp', 'uploads')
    FileUtils.rm_rf(upload_dir) if Dir.exist?(upload_dir)

    temp_file = Tempfile.new(['test_image', '.jpg'])
    temp_file.write("test_content" * 100)
    temp_file.rewind

    post '/api/upload/image', params: { file: Rack::Test::UploadedFile.new(temp_file.path, 'image/jpeg') }, headers: authenticate_user(@user)

    # 应该成功，因为控制器会重新创建目录
    assert_response :success

    # 恢复目录
    FileUtils.mkdir_p(upload_dir)

    temp_file.close
    temp_file.unlink
  end

  test "should return not found for invalid route" do
    # 测试无效的路由
    post '/api/upload/invalid', headers: authenticate_user(@user)
    assert_response :not_found
  end

  private

  def authenticate_user(user)
    token = user.generate_jwt_token
    { "Authorization" => "Bearer #{token}" }
  end
end