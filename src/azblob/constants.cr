module AZBlob
  ServiceVersion = "2024-05-04"
  DEFUALT_SCHEME = "https"
  DEFUALT_SUFFIX = "core.windows.net"

  AZURE_ENDPOINT_URL        = "https://%s.blob.core.windows.net/"
  AZURE_ENDPOINT_URL_SHARED = "https://%s.blob.core.windows.net/?%s"

  AZURE_STORAGE_ACCOUNT_NAME            = ENV["AZURE_STORAGE_ACCOUNT_NAME"]?
  AZURE_STORAGE_ACCOUNT_KEY             = ENV["AZURE_STORAGE_ACCOUNT_KEY"]?
  AZURE_STORAGE_SHARED_ACCESS_SIGNATURE = ENV["AZURE_STORAGE_SHARED_ACCESS_SIGNATURE"]?

  AZURE_STORAGE_CONNECTION_STRING = ENV["AZURE_STORAGE_CONNECTION_STRING"]?

  INVALID_CONNECTION_STRING = %(
  connection string is either blank or malformed. The expected connection string should contain key value pairs separated by semicolons.
  For example 'DefaultEndpointsProtocol=https;AccountName=<accountName>;AccountKey=<accountKey>;EndpointSuffix=core.windows.net'
  )

  DefaultConcurrency = 5

  DefaultDownloadBlockSize = (4 * 1024 * 1024).to_i64 # 4MB
  # MaxUploadBlobBytes indicates the maximum number of bytes that can be sent in a call to Upload.
  MaxUploadBlobBytes = 256 * 1024 * 1024 # 256MB

  # MaxStageBlockBytes indicates the maximum number of bytes that can be sent in a call to StageBlock.
  MaxStageBlockBytes = 4000_i64 * 1024 * 1024 # 4GB

  # MaxBlocks indicates the maximum number of blocks allowed in a block blob.
  MaxBlocks = 50000

  ContentTypeAppJSON   = "application/json"
  ContentTypeAppXML    = "application/xml"
  ContentTypeTextPlain = "text/plain"
  ContentTypeBinary    = "application/octet-stream"

  HeaderAuthorization          = "Authorization"
  HeaderXmsDate                = "x-ms-date"
  HeaderAuxiliaryAuthorization = "x-ms-authorization-auxiliary"
  HeaderAzureAsync             = "Azure-AsyncOperation"
  HeaderContentLength          = "Content-Length"
  HeaderContentEncoding        = "Content-Encoding"
  HeaderContentLanguage        = "Content-Language"
  HeaderContentType            = "Content-Type"
  HeaderContentMD5             = "Content-MD5"
  HeaderIfModifiedSince        = "If-Modified-Since"
  HeaderIfMatch                = "If-Match"
  HeaderIfNoneMatch            = "If-None-Match"
  HeaderIfUnmodifiedSince      = "If-Unmodified-Since"
  HeaderRange                  = "Range"
  HeaderXmsVersion             = "x-ms-version"
  HeaderFakePollerStatus       = "Fake-Poller-Status"
  HeaderLocation               = "Location"
  HeaderOperationLocation      = "Operation-Location"
  HeaderRetryAfter             = "Retry-After"
  HeaderRetryAfterMS           = "Retry-After-Ms"
  HeaderUserAgent              = "User-Agent"
  HeaderWWWAuthenticate        = "WWW-Authenticate"
  HeaderXMSClientRequestID     = "x-ms-client-request-id"
  HeaderXMSRequestID           = "x-ms-request-id"
  HeaderXMSErrorCode           = "x-ms-error-code"
  HeaderXMSRetryAfterMS        = "x-ms-retry-after-ms"
end
