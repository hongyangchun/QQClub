class Api::UploadsController < Api::V1::BaseController
  before_action :authenticate_user!

  # POST /api/upload/image
  def create
    return render_error(message: '请选择要上传的图片', code: 'NO_FILE') unless params[:image]

    # 检查文件类型
    unless params[:image].respond_to?(:content_type) && params[:image].content_type&.start_with?('image/')
      return render_error(message: '只支持上传图片文件', code: 'INVALID_FILE_TYPE')
    end

    # 检查文件大小 (最大 5MB)
    if params[:image].size > 5.megabytes
      return render_error(message: '图片大小不能超过 5MB', code: 'FILE_TOO_LARGE')
    end

    begin
      # 生成唯一文件名
      require 'securerandom'
      file_extension = get_file_extension(params[:image].content_type)
      filename = "#{SecureRandom.uuid}_#{Time.current.to_i}#{file_extension}"

      # 保存到本地存储
      saved_path = save_uploaded_image(params[:image], filename)

      # 生成访问URL
      image_url = generate_image_url(saved_path)

      render_success(
        data: {
          url: image_url,
          filename: filename,
          size: params[:image].size,
          content_type: params[:image].content_type,
          local_path: saved_path
        },
        message: '图片上传成功'
      )
    rescue => e
      Rails.logger.error "图片上传失败: #{e.message}"
      render_error(
        message: '图片上传失败',
        code: 'UPLOAD_FAILED',
        details: e.message
      )
    end
  end

  private

  # 为了安全，可以添加文件白名单验证
  def allowed_file_types
    ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
  end

  def max_file_size
    5.megabytes
  end

  # 获取文件扩展名
  def get_file_extension(content_type)
    extension_map = {
      'image/jpeg' => '.jpg',
      'image/jpg' => '.jpg',
      'image/png' => '.png',
      'image/gif' => '.gif',
      'image/webp' => '.webp'
    }
    extension_map[content_type] || '.jpg'
  end

  # 保存上传的图片到本地
  def save_uploaded_image(uploaded_file, filename)
    # 创建上传目录
    upload_dir = Rails.root.join('public', 'uploads', 'images')
    FileUtils.mkdir_p(upload_dir) unless Dir.exist?(upload_dir)

    # 按日期创建子目录
    date_dir = upload_dir.join(Time.current.strftime('%Y%m%d'))
    FileUtils.mkdir_p(date_dir) unless Dir.exist?(date_dir)

    # 完整文件路径
    file_path = date_dir.join(filename)

    # 保存文件
    File.open(file_path, 'wb') do |file|
      file.write(uploaded_file.read)
    end

    # 返回相对路径
    File.join('uploads', 'images', Time.current.strftime('%Y%m%d'), filename)
  end

  # 生成图片访问URL
  def generate_image_url(saved_path)
    # 在开发环境中，我们使用相对路径
    if Rails.env.development?
      "#{request.protocol}#{request.host_with_port}/#{saved_path}"
    else
      # 生产环境应该使用CDN或完整的域名
      "#{request.protocol}#{request.host_with_port}/#{saved_path}"
    end
  end
end
