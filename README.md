[![Build Status](https://secure.travis-ci.org/igor-alexandrov/paperclip-aws.png)](http://travis-ci.org/igor-alexandrov/paperclip-aws)

# Paperclip storage module to use Amazon S3 with official 'aws-sdk' gem #

**paperclip-aws** is a full featured storage module that supports all S3 locations (American, European and Japanese) without any additional hacking.

## Features ##
  
* supports US, European and Japanese S3 instances;
* supports both `http` and `https` urls;
* supports expiring urls;
* supports different permissions for each Paperclip style;
* can generate urls for `read`, `write` и `delete` operations;
* correctly sets content-type of uploaded files;
* ability to set content-disposition of uploaded files;
* **supports amazon server side encryption** (thanks to [pvertenten](https://github.com/pvertenten));
* highly compatible with included in Paperclip S3 storage module


## Requirements ##

* [paperclip][0] ~> 2.4
* [aws-sdk][1] >= 1.2.0

## Installation ##

    gem install paperclip-aws

After this add 'paperclip-aws' to your `Gemfile` or `environment.rb`
    
## Common Usage ##

    class SomeS3Attachment < ActiveRecord::Base
      def self.s3_config
        @@s3_config ||= YAML.load(ERB.new(File.read("#{Rails.root}/config/s3.yml")).result)[Rails.env]    
      end

      has_attached_file :data,
                        :styles => {
                          :thumb => [">75x"],
                          :medium => [">600x"]
                        },                    
                        :storage => :aws,
                        :s3_credentials => {
                          :access_key_id => self.s3_config['access_key_id'],
                          :secret_access_key => self.s3_config['secret_access_key'],
                          :endpoint => self.s3_config['endpoint']
                        },
                        :bucket => self.s3_config['bucket'],                    
                        :s3_host_alias => self.s3_config['s3_host_alias'],
                        :s3_permissions => :public_read,
                        :s3_protocol => 'http',
                        :s3_options => {
                          :sse => 'AES256',
                          :storage_class => :reduced_redundancy,
                          :content_disposition => 'attachment'
                        },
                        
                        :path => "company_documents/:id/:style/:data_file_name"  
                        
      # You also can modify @s3_options hash directly.
      before_save do
        self.data.s3_options[:content_disposition] = "attachment; filename=#{self.data_file_name}"
        self.data.s3_options[:sse] = true if self.confidential_information?
        self.data.s3_options[:storage_class] = true if self.unimportant_information?
      end                          
    end

Create link for file that will expire in 10 seconds after it was created. Useful when redirecting user to file.

    file.data.url(:original, { :expires => Time.now + 10.seconds, :protocol => 'https' })

                      
## Configuration ##

### :endpoint ###
Endpoint where your bucket is located. Default is `'s3.amazonaws.com'` which is for 'US Standard' region.

You can find full list of endpoints and regions [here](http://aws.amazon.com/articles/3912#s3)

### :s3_permissions  ###
Sets permissions to your objects. Values are:

    :private
    :public_read
    :public_read_write
    :authenticated_read
    :bucket_owner_read
    :bucket_owner_full_control

You can setup permnissions globally for object or per style:    

    :s3_permissions => :public_read
    
    
    :s3_permissions => {
      :thumb => :public_read,
      :medium => :authenticated_read,
      :default => :authenticated_read
    }
   
### :s3_protocol ###
Default protocol to use: `'http'` or `'https'`.

### :s3_options ###
Hash of additional options. Available options are:

* `:sse` –  `'AES256'` (the only available encryption now)
* `:storage_class` – `:standard` (default) or `:reduced_redundancy`
* `:content_disposition`


## How `paperclip-aws` creates urls?

'paperclip-aws' redefines Paperclip `url` method to get object URL.

    def url(style=default_style, options={})
    end

Supported options are:

* `:protocol` — `'http'` or `'https'`

  Use this options to redefine default protocol, configured in model.

* `:expires`

  Sets the expiration time of the URL; after this time S3 will return an error if the URL is used.  This can be an integer (to specify the number of seconds after the current time), a string (which is parsed as a date using Time#parse), a Time, or a DateTime object. This option defaults to one hour after the current time.
  
  Default is set to 3600 seconds.

* `:action`
  
  Method, the HTTP verb or object method for which the returned URL will be valid.  Valid values:
  
  * `:get` or `:read`
  * `:put` or `:write`
  * `:delete`
  
  Default is set to `:read`, which is the most common used.

## Can I use it in production?

Yes, usage of **paperclip-aws** is confirmed by several rather big projects:

* [www.sdelki.ru](http://www.sdelki.ru)
* [www.lienlog.com](http://www.lienlog.com) (opens for public in December 2011)
* [www.sharypic.com](http://www.sharypic.com) (soon)

I hope that it is used in a lot of other projects, if you know them – let me know.
    
[0]: https://github.com/thoughtbot/paperclip
[1]: https://github.com/amazonwebservices/aws-sdk-for-ruby