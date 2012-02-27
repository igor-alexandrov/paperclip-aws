# coding: UTF-8

require 'paperclip'
require 'aws-sdk'
require 'uri'

module Paperclip
  module Storage
    module Aws
      def self.extended base
        begin
          require 'aws-sdk'
        rescue LoadError => e
          e.message << " (You may need to install the aws-sdk gem)"
          raise e
        end unless defined?(AWS::Core)
        
        attr_accessor :s3_credentials, :s3_bucket, :s3_permissions, :s3_options, :s3_protocol, :s3_host_alias
        
        base.instance_eval do   
          self.setup_s3_credentials
          self.setup_s3_bucket                 
          self.setup_s3_permissions          
          self.setup_s3_protocol
          self.setup_s3_options
          self.setup_s3_host_alias
        end        
      end
      
      def s3
        @s3 ||= AWS::S3.new(
          :access_key_id => @s3_credentials[:access_key_id],
          :secret_access_key => @s3_credentials[:secret_access_key],
          :s3_endpoint => @s3_endpoint
        )        
      end
      
      def url(style=default_style, options={})
        if self.original_filename.nil? 
          # default_url = @default_url.is_a?(Proc) ? @default_url.call(self) : @default_url
          # return interpolate(default_url, style)          
          return super
        end
        
        if options[:expires].present? || options[:action].present?
          options.reverse_merge!({
            :expires => 60*60,
            :action => :read
          })          
          secure = ( self.choose_protocol(style, options) == 'https' )                   
          return self.s3.buckets[@s3_bucket].objects[path(style).gsub(%r{^/}, "")].url_for(options[:action], {  :secure => secure, :expires => options[:expires] }).to_s
        else
          if @s3_host_alias.present?
            url = "#{choose_protocol(style, options)}://#{@s3_host_alias}/#{path(style).gsub(%r{^/}, "")}"
          else
            url = "#{choose_protocol(style, options)}://#{@s3_endpoint}/#{@s3_bucket}/#{path(style).gsub(%r{^/}, "")}"
          end    
          return URI.escape(url)
        end              
      end
      
      def bucket
        @bucket ||= self.s3.buckets[@s3_bucket]
      end
      
      def s3_bucket=(value)
        @bucket = nil
                
        @s3_bucket = value
        @s3_bucket = @s3_bucket.call(self) if @s3_bucket.is_a?(Proc)
      end
      
      def versions(style = default_style)
        begin
          return nil unless self.bucket.versioning_enabled?
          self.bucket.objects[path(style)].versions          
        rescue AWS::S3::Errors::Base => e
          log "ERROR: Error occured while fetching versions for `#{path(style)}`. Probably versions are disabled or suspended for `#{self.bucket.name}` bucket."
          return nil
        end
      end
            
      def exists?(style = default_style)
        if path(style).nil? || path(style).to_s.strip == ""
          return false
        end
        begin
          return self.bucket.objects[path(style)].exists?
        rescue AWS::S3::Errors::Base
          return false
        end
      end

      def choose_protocol(style, options={})
        if options[:protocol].present?
          return options[:protocol].to_s
        else
          return @s3_protocol.is_a?(Proc) ? @s3_protocol.call(style, self) : @s3_protocol
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
        file.write(self.bucket.objects[path(style)].read)
        file.rewind
        return file
      end

      def create_bucket
        self.s3.buckets.create(@s3_bucket)
      end

      def flush_writes #:nodoc:
        @queued_for_write.each do |style, file|
          begin
            log "Saving #{path(style)}"
            
            self.s3.buckets[@s3_bucket].objects[path(style)].write({
              :file => file.path,
              :acl => @s3_permissions[:style.to_sym] || @s3_permissions[:default],
              :content_type => file.content_type.to_s.strip
            }.reverse_merge(@s3_options))
          rescue AWS::S3::Errors::NoSuchBucket => e
            create_bucket
            retry
          rescue AWS::Errors::Base => e
            raise
          end
        end
        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.each do |path|
          begin
            log "Deleting #{path}"
            self.s3.buckets[@s3_bucket].objects[path].delete
          rescue AWS::Errors::Base => e
            raise
          end
        end
        @queued_for_delete = []
      end
      
    # PRIVATE METHODS        
      def setup_s3_credentials
        if @options[:s3_credentials].present?
          @s3_credentials = self.parse_s3_credentials(@options[:s3_credentials]).stringify_keys
          env = Object.const_defined?(:Rails) ? Rails.env : nil
          
          @s3_credentials = (@s3_credentials[env] || @s3_credentials).symbolize_keys              
          @s3_endpoint = @s3_credentials[:endpoint] || 's3.amazonaws.com'
        else
          raise ArgumentError, "missing required :s3_credentials option"
        end
      end
      protected :setup_s3_credentials
      
      def parse_s3_credentials(creds)
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
      protected :parse_s3_credentials
      
      def setup_s3_bucket
        if @options[:bucket].present?
          log "DEPRECATION WARNING: Passing  `:bucket` options to paperclip is deprecated. Please use `:s3_bucket` instead."
        end
        
        if @options[:s3_bucket].present? || @s3_credentials[:bucket].present? || @options[:bucket].present?
          self.s3_bucket = @options[:s3_bucket] || @s3_credentials[:bucket] || @options[:bucket]     
        else
          raise ArgumentError, "missing required :s3_bucket option"
        end
      end
      protected :setup_s3_bucket
      
      def setup_s3_permissions
        @s3_permissions = self.parse_s3_permissions(@options[:s3_permissions])
      end
      protected :setup_s3_permissions
      
      def parse_s3_permissions(permissions)
        if permissions.is_a?(Hash)
          permissions[:default] = permissions[:default] || :public_read
        else
          permissions = { :default => permissions || :public_read }
        end
        permissions                
      end
      protected :parse_s3_permissions
      
      def setup_s3_protocol
        @s3_protocol = @options[:s3_protocol] ||
          Proc.new do |style, attachment|
            permission  = (@s3_permissions[style.to_sym] || @s3_permissions[:default])
            permission  = permission.call(attachment, style) if permission.is_a?(Proc)
            (permission == :public_read) ? 'http' : 'https'
          end                  
      end
      protected :setup_s3_protocol
        
      def setup_s3_options
        @s3_options     = (@options[:s3_options] || {}).symbolize_keys
        
        # setup Amazon Server Side encryption
        @s3_options.reverse_merge!({
          :sse => false,
          :storage_class => :standard,
          :content_disposition => nil
        })
        @s3_options[:server_side_encryption] ||= @s3_options.delete(:sse)                            
      end
      protected :setup_s3_options
      
      
      def setup_s3_host_alias
        @s3_host_alias = @options[:s3_host_alias]
        @s3_host_alias = @s3_host_alias.call(self) if @s3_host_alias.is_a?(Proc)                            
      end
      protected :setup_s3_host_alias
    end
  end
end
