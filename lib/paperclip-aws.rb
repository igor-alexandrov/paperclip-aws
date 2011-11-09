# coding: UTF-8

require 'paperclip'

module Paperclip
  module Storage
    module Aws
      def self.extended base
        begin
          require 'aws-sdk'
        rescue LoadError => e
          e.message << " (You may need to install the aws-sdk gem)"
          raise e
        end unless defined?(AWS)

        base.instance_eval do
          @s3_credentials   = parse_credentials(@options[:s3_credentials])
          
          # setup bucket
          @s3_bucket = @options[:s3_bucket] || @s3_credentials[:bucket]
          @s3_bucket = @s3_bucket.call(self) if @s3_bucket.is_a?(Proc) 
          
          # setup permissions
          @s3_acl           = @options[:s3_acl]           || :public_read
          @s3_sse = @options[:s3_sse]

          # choose what storage class we use, 'standard' or 'reduced_redundancy'
          @s3_storage_class = @options[:s3_storage_class] || :standard
          
          @s3_protocol      = @options[:s3_protocol]      || 'http'
          @s3_headers       = @options[:s3_headers]       || {}
          @s3_host_alias    = @options[:s3_host_alias]
          @s3_host_alias    = @s3_host_alias.call(self) if @s3_host_alias.is_a?(Proc)
          
          @s3_endpoint = @s3_credentials[:endpoint] || 's3.amazonaws.com'
          
          @s3 = AWS::S3.new(
            :access_key_id => @s3_credentials[:access_key_id],
            :secret_access_key => @s3_credentials[:secret_access_key],
            :s3_endpoint => @s3_endpoint
          )
        end
      end
              
      def url(style=default_style, options={})
        if self.original_filename.nil? 
          default_url = @default_url.is_a?(Proc) ? @default_url.call(self) : @default_url
          return interpolate(default_url, style)          
        end
        
        if options[:expires].present? || options[:action].present?
          options.reverse_merge!({
            :expires => 60*60,
            :action => :read
          })          
          secure = ( self.choose_protocol(options) == 'https' )                   
          @s3.buckets[@s3_bucket].objects[path(style)].url_for(options[:action], {  :secure => secure, :expires => options[:expires] }).to_s
        else
          if @s3_host_alias.present?
            "#{choose_protocol(options)}://#{@s3_host_alias}/#{path(style).gsub(%r{^/}, "")}"
          else
            "#{choose_protocol(options)}://#{@s3_endpoint}/#{@s3_bucket}/#{path(style).gsub(%r{^/}, "")}"
          end        
        end
      end
      
      def bucket_name
        @s3_bucket
      end

      def parse_credentials(creds)
        creds = find_credentials(creds).stringify_keys
        env = Object.const_defined?(:Rails) ? Rails.env : nil
        (creds[env] || creds).symbolize_keys
      end

      def exists?(style = default_style)
        if path(style).nil? || path(style).to_s.trim == ""
          return false
        end
        begin
          return @s3.buckets[@s3_bucket].objects[path(style)].exists?
        rescue AWS::S3::Errors::NoSuchKey
          return false
        end
      end

      def choose_protocol(options={})
        if options[:protocol].present?
          return options[:protocol].to_s
        else
          return @s3_protocol
        end
      end

      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file style = default_style
        return @queued_for_write[style] if @queued_for_write[style]
        filename = path(style)
        extname  = File.extname(filename)
        basename = File.basename(filename, extname)
        file = Tempfile.new([basename, extname])
        file.binmode
        file.write(@s3.buckets[@s3_bucket].objects[path(style)].read)
        file.rewind
        return file
      end

      def create_bucket
        @s3.buckets.create(@s3_bucket)
      end

      def flush_writes #:nodoc:
        @queued_for_write.each do |style, file|
          begin
            log("saving #{path(style)}")

            @s3.buckets[@s3_bucket].objects[path(style)].write(
              file,
              :acl => @s3_acl,
              :storage_class => @s3_storage_class,
              :content_type => file.content_type,
              :server_side_encryption => @s3_sse
            )
          rescue AWS::S3::Errors::NoSuchBucket => e
            create_bucket
            retry
          rescue AWS::S3::Errors::Base => e
            raise
          end
        end
        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.each do |path|
          begin
            log("deleting #{path}")
            @s3.buckets[@s3_bucket].objects[path].delete
          rescue AWS::S3::Errors::Base => e
            raise
          end
        end
        @queued_for_delete = []
      end

      def find_credentials creds
        case creds
        when File
          YAML::load(ERB.new(File.read(creds.path)).result)
        when String, Pathname
          YAML::load(ERB.new(File.read(creds)).result)
        when Hash
          creds
        else
          raise ArgumentError, "Credentials are not a path, file, or hash."
        end
      end
      private :find_credentials

    end
  end
end
