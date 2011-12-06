require './test/helper'

class AwsStorageTest < Test::Unit::TestCase
  def rails_env(env)
    silence_warnings do
      Object.const_set(:Rails, stub('Rails', :env => env))
    end
  end
  
  def default_model_options(options={})
    {
      :storage => :aws,
      :bucket => "testing",
      :s3_credentials => {
        :access_key_id => "ACCESS_KEY_ID",
        :secret_access_key => "SECRET_ACCESS_KEY"
      },
      :path => ":attachment/:basename.:extension"
    }.deep_merge!(options)
  end
  
  context "Parsing S3 credentials" do
    setup do      
      rebuild_model default_model_options

      @dummy = Dummy.new
      @avatar = @dummy.avatar
    end
    
    should "get the correct credentials when RAILS_ENV is production" do
      rails_env("production")
      
      assert_equal(
        { :access_key_id => "12345" },
        @avatar.parse_credentials(
          :production => { :access_key_id => '12345' },
          :development => { :access_key_id => '54321' }
        )
      )
    end
    
    should "get the correct credentials when RAILS_ENV is development" do
      rails_env("development")
      
      assert_equal(
        { :access_key_id => "54321" },
        @avatar.parse_credentials(
          :production => { :access_key_id => '12345' },
          :development => { :access_key_id => '54321' }
        )
      )  
    end
    
    should "return the argument if the key does not exist" do
      rails_env("not really an env")
      assert_equal({:test => "12345"}, @avatar.parse_credentials(:test => "12345"))
    end
    
  end
  
  context "Working with endpoints" do
    should "return a correct url based on a path with default endpoint" do
      rebuild_model default_model_options
      
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
      
      assert_match %r{^http://s3.amazonaws.com/testing/avatars/stringio.txt}, @dummy.avatar.url
    end
    
    
    should "return a correct url based on a path with custom endpoint" do
      rebuild_model default_model_options(:s3_credentials => { :endpoint => 's3-eu-west-1.amazonaws.com' })

      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
      
      assert_match %r{^http://s3-eu-west-1.amazonaws.com/testing/avatars/stringio.txt}, @dummy.avatar.url
    end    
  end
  
  context "Working with protocols" do
    should "return a correct url with http protocol predefined" do
      rebuild_model default_model_options(:s3_protocol => 'http')
      
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
      
      assert_match  /\Ahttp:\/\/.+/,  @dummy.avatar.url
    end
    
    
    should "return a correct url with https protocol predefined" do
      rebuild_model default_model_options(:s3_protocol => 'https')
      
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
      
      assert_match  /\Ahttps:\/\/.+/,  @dummy.avatar.url
    end
    
    should "return a correct protocol protocol based on s3_permissions" do
      rebuild_model default_model_options(:s3_permissions => :public_read)
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")      
      assert_match  /\Ahttp:\/\/.+/,  @dummy.avatar.url
      
      rebuild_model default_model_options(:s3_permissions => :private)
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")      
      assert_match  /\Ahttps:\/\/.+/,  @dummy.avatar.url
      
      rebuild_model default_model_options(:s3_permissions => :public_read_write)
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")      
      assert_match  /\Ahttps:\/\/.+/,  @dummy.avatar.url
      
      rebuild_model default_model_options(:s3_permissions => :authenticated_read)
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")      
      assert_match  /\Ahttps:\/\/.+/,  @dummy.avatar.url
      
      rebuild_model default_model_options(:s3_permissions => :bucket_owner_read)
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")      
      assert_match  /\Ahttps:\/\/.+/,  @dummy.avatar.url
      
      rebuild_model default_model_options(:s3_permissions => :bucket_owner_full_control)
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")      
      assert_match  /\Ahttps:\/\/.+/,  @dummy.avatar.url      
    end
    
    should "return a correct url when protocol explicitely defined from url" do
      rebuild_model default_model_options
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")      
      assert_match  /\Ahttps:\/\/.+/,  @dummy.avatar.url(:original, :protocol => "https")
      
      rebuild_model default_model_options(:s3_permissions => :private)
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")      
      assert_match  /\Ahttp:\/\/.+/,  @dummy.avatar.url(:original, :protocol => "http")      
    end
  end
  
  context "Working with expiring urls" do
    should "return a correct url which contains 'Expires' parameter" do
      rebuild_model default_model_options
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
      
      assert_match  /\Ahttp:\/\/.+Expires.+/,  @dummy.avatar.url(:original, :expires => 1.day)      
    end
  end
  
  context "Working with default urls" do
    should "return a correct default url without data initialized" do
      rebuild_model default_model_options
      @dummy = Dummy.new
      
      assert_match  /avatars\/original\/missing/,  @dummy.avatar.url
      assert_match  /avatars\/another\/missing/,  @dummy.avatar.url(:another)
    end
    
    should "return a correct default url without data initialized and with default_url parameter set" do
      rebuild_model default_model_options(:default_url => '/:attachment/:style_missing.png')
      @dummy = Dummy.new
      
      assert_match  /avatars\/original_missing/,  @dummy.avatar.url
      assert_match  /avatars\/another_missing/,  @dummy.avatar.url(:another)
    end
    
  end
  
  
  context "An attachment that uses S3 for storage and has styles that return different file types" do
    setup do
      rebuild_model default_model_options(:styles  => { :large => ['500x500#', :jpg] })

      @dummy = Dummy.new
      @dummy.avatar = File.new(fixture_file('5k.png'), 'rb')
    end

    should "return a url containing the correct original file mime type" do
      assert_match /.+\/5k.png/, @dummy.avatar.url
    end

    should "return a url containing the correct processed file mime type" do
      assert_match /.+\/5k.jpg/, @dummy.avatar.url(:large)
    end
  end
  
  context "An attachment that uses S3 for storage and has spaces in file name" do
    setup do
      rebuild_model default_model_options(:styles  => { :large => ['500x500#', :jpg] })
      
      @dummy = Dummy.new
      @dummy.avatar = File.new(fixture_file('spaced file.png'), 'rb')
    end

    should "return an unescaped version for path" do
      assert_match /.+\/spaced file\.png/, @dummy.avatar.path
    end

    should "return an escaped version for url" do
      assert_match /.+\/spaced%20file\.png/, @dummy.avatar.url
    end
  end
  
  context "An attachment with AWS storage" do
    setup do
      rebuild_model default_model_options
    end

    should "be extended by the AWS module" do
      assert Dummy.new.avatar.is_a?(Paperclip::Storage::Aws)
    end

    should "not be extended by the Filesystem module" do
      assert ! Dummy.new.avatar.is_a?(Paperclip::Storage::Filesystem)
    end
  end
end