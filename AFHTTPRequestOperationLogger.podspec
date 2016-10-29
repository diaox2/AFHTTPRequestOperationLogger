Pod::Spec.new do |s|
  s.name     = 'AFHTTPRequestOperationLogger'
  s.version  = '2.1.2'
  s.license  = 'MIT'
  s.summary  = 'AFNetworking Extension for HTTP Request Logging'
  s.homepage = 'https://github.com/diaox2/AFHTTPRequestOperationLogger'
  s.authors  = { 'Mattt Thompson' => 'm@mattt.me' }
  s.source   = { :git => 'https://github.com/diaox2/AFHTTPRequestOperationLogger.git', :tag => 'v2.1.2' }
  s.source_files = 'AFHTTPRequestOperationLogger.{h,m}'
  s.requires_arc = true

  s.dependency 'AFNetworking', '~> 2.0'
  s.platforms = {"ios" => "7.0"}

end
