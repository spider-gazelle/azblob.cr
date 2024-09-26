# azblob.cr

Azure Blob Storage shard for Crystal. Supports

>  #### Use concurrency when upload/download size exceeds Azure given limits for one request


* #### Containers
  * Create
  * Delete
  * List

* #### Blob
  * List
  * Upload
  * Download
  * Delete
  
* #### BlockBlob
  * Upload
  * Download

*  #### Shared Storage Access (SAS)
     * Blob
     * Container


> `List` operations are Paginated

### Environment Variables

  * `AZURE_STORAGE_ACCOUNT_NAME`
  * `AZURE_STORAGE_ACCOUNT_KEY`
  * `AZURE_STORAGE_CONNECTION_STRING`
  * `https_proxy` - Proxy address (if used)
  * `http_proxy` - Proxy address (if used)
  

Use either `AZURE_STORAGE_CONNECTION_STRING` or combination `AZURE_STORAGE_ACCOUNT_NAME` and `AZURE_STORAGE_ACCOUNT_KEY`

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     azblob:
       github: spider-gazelle/azblob.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "azblob"

# Create Client via one of the multiple options given
client = AZBlob.client_from_env  # client from environment variables 
# OR
client = AZBlob.client(connection_string, optional_proxy) # client with given connection string via code
# OR
client = AZBlob::Client.new(config) # client with Client::Config object

# Create container
client.create_container(container-name, metadata) # metadata is optional key/value hash

# Delete container
client.delete_container(container-name)

# List containers
iter = client.list_containers(max_results: 3)
iter.each do |page|
  page.containers.each do{ |c| puts c.name }
end


# List blobs
iter = client.list_blobs(max_results: 3)
iter.each do |page|
  .... # page other attributes
  page.blobs.each .....
end

# upload blob
client.put_blob(...) # various overloads provided

# download blob
client.get_blob(container,blob-name, options)

# Pre-Sign URL (SAS URL)

client.blob_sas(.....)
client.container_sas(.....)
```

## Development

## Contributing

1. Fork it (<https://github.com/spider-gazelle/azblob.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Ali Naqvi](https://github.com/naqvi) - creator and maintainer
