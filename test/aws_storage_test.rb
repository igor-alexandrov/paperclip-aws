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
      Rails.stubs(:const_defined?)
      
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
    setup do
      Rails.stubs(:const_defined?)      
    end

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
    setup do
      Rails.stubs(:const_defined?)      
    end
    
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
    
  end
end