module Api
  class UploadsController < Api::ApplicationController
    before_action :authenticate_user!

    # POST /api/upload/image
    def create
      return render json: { error: '请选择图片文件' }, status: :bad_request unless params[:file]

      uploaded_file = params[:file]

      # 验证文件类型
      unless uploaded_file.content_type.in?(['image/jpeg', 'image/jpg', 'image/png', 'image/gif'])
        return render json: { error: '只支持 JPG、PNG、GIF 格式的图片' }, status: :bad_request
      end

      # 验证文件大小（最大5MB）
      if uploaded_file.size > 5.megabytes
        return render json: { error: '图片大小不能超过5MB' }, status: :bad_request
      end

      begin
        # 生成唯一文件名
        file_name = "#{SecureRandom.uuid}_#{uploaded_file.original_filename}"

        # 这里应该将文件存储到云存储服务，如阿里云OSS、腾讯云COS等
        # 暂时存储到本地，生产环境需要使用云存储
        file_path = Rails.root.join('tmp', 'uploads', file_name)
        FileUtils.mkdir_p(File.dirname(file_path))

        File.open(file_path, 'wb') do |file|
          file.write(uploaded_file.read)
        end

        # 生成访问URL（开发环境使用本地路径）
        url = "/uploads/#{file_name}"

        render json: {
          message: '图片上传成功',
          url: url,
          file_name: file_name
        }

      rescue => e
        Rails.logger.error "图片上传失败: #{e.message}"
        render json: { error: '图片上传失败，请重试' }, status: :internal_server_error
      end
    end

    private

    def authenticate_user!
      return head :unauthorized unless current_user
    end
  end
end